#!/usr/bin/env python3

import dateutil.parser as dtParse
import logging
import argparse
import os,sys
import subprocess as bt
import warnings
import json
import yaml
import pandas as pd
import numpy as np
import cx_Oracle as cxo
import itertools, collections
import re
import time
import pwd
import math
import random
import smtplib
import socket
from email.mime.text import MIMEText
from tqdm import tqdm #progressBar'
import aggr
from rxpayermix import RxPayermix, PayerType

LOGGER = logging.getLogger(__name__)

#function names for easy searching:
#qw,createSettingDict,writeSettingFile,yamlfyCfgFile,getOracleSql,normalizeDate,getHeaders,
#subsetTab,loadTable,dropTable,getProfileData,convertCsv,sendEmail,getRxPayermix,atoi,naturalSort

#python implementation of qw
def qw(stringList):
	return tuple(stringList.split())

#Input: (config) Pathname for config file.
#Function: Creates a dict of Options => Array of values for each non-commented or empty line
#Output: Returns the dict
def createSettingDict(config,equalDelim="="):	
	setDict = {}
	ifh = open(config,"r")
	lines = ifh.readlines()
	for line in lines:
		line = line.rstrip()
		if(re.search("^#|^$",line)):
			continue
		elif(not re.search(equalDelim,line)):
			exit("Invalid line! No " + equalDelim + " found for setting\nError line:\t\t" + line + "\n")
		#print(line)
		optVal = line.split(equalDelim,1)
		opt = optVal[0].strip()
		val = optVal[1].split()
		#print(optVal)
		#print(opt)
		#print(val)
		setDict[opt] = val
	ifh.close()
	return setDict

#Input: config-> a dict representation of a settings.cfg file for loadAggr.pl files
#Function: generates the expected settings.cfg file so that the layout is centralized on a yaml file
#Output: generates a settings.cfg file (output file location can be changed)
def writeSettingFile(config,outFile="settings.cfg",yamlPath="",cfgType=None):
	if "CFG_TYPE" in config:
		cfgType = config["CFG_TYPE"][0]
	#print(config,outFile,cfgType)
	#print("\n\n")
	yamlFile = ""
	if yamlPath != "":
		yamlFile = yamlPath
	elif cfgType == None:
		print(config)
		exit("Cannot determine cfg file type")
	else:
		#print(dir(aggr))
		#print((aggr.__path__._path[0]))
		yamlFile = aggr.__path__._path[0] + "/" + cfgType.lower() + "/" + cfgType.lower() + "Settings.yaml"
	if not os.path.exists(yamlFile):
		exit("settings.cfg yaml file not found: " + yamlFile)
	#print(yamlFile)
	#os.system("cat " + yamlFile)
	yifh = open(yamlFile,'r')
	tempData = yaml.safe_load(yifh)
	#print(tempData)
	cofh = open(outFile,'w')
	for header in tempData:
		if not "JOB_ID" in config and header == "Job_Id":
			continue
		#print(header)
		cofh.write("#-------------" + header + "-------------\n\n")
		for var in tempData[header]:
			req = tempData[header][var]["req"]
			com = tempData[header][var]["com"]
			val = tempData[header][var]["val"]
			if var in config:
				val = "\t".join(config[var])
			#print("\t" + ','.join([var,req,com]))
			#print("\t\t" + val)
			cofh.write("# " + req + ": " + com + "\n")
			cofh.write(var + " = " + val + "\n\n")
	cofh.close()

def yamlfyCfgFile(cfgFile,outFile):
	cifh = open(cfgFile,"r")
	yamlStr = {}
	header = None
	req = None
	comm = None
	var = None
	val = None
	for line in cifh:
		line = line.strip()
		if line == "":
			continue
		#print(line)
		#found a header
		if re.search("^#--",line):
			header = re.sub("(^#-*|-*$)","",line)
			print(header)
			yamlStr[header] = {}
		#found a comment
		elif re.search("^#",line):
			req = re.sub("(^# |:.*$)","",line)
			comm = re.sub("^.*: ","",line)
			print("\t" + req)
			print("\t" + comm)
		#found a variable
		elif re.search("=",line):
			var = re.sub(" =.*","",line)
			val = re.sub(".*=\s*","",line)
			print("\t\t" + var)
			print("\t\t" + val)
			yamlStr[header][var] = {}
			yamlStr[header][var]["req"] = req
			yamlStr[header][var]["com"] = comm
			yamlStr[header][var]["val"] = val
	cifh.close()
	#print(yamlStr)
	yofh = open(outFile,"w")
	yofh.write(yaml.dump(yamlStr,sort_keys=False))
	yofh.close()
	return True

#Input: oraInst=> The particular Oracle Instance you wish to use (e.g. PLDELDB)
#     oraUser=> The appropriate User Name for your given instance
#     oraPass=> The appropriate Password for your given User Name
#     sql=> The sql statement you wish to query on the given oraInstance
#     toFile=> print resultant query to file instead of returning a DataFrame
#Function: Runs an SQL query and returns the result as a pandas DataFrame
#Output: Returns a pandas DataFrame, or instead generates a file if "toFile" option supplied
def getOracleSql(oraInst,oraUser,oraPass,sql,outString="",toFile=""):
	# Establish the database connection
	conn = cxo.connect(oraUser,oraPass,oraInst)
	# Obtain a cursor
	cursor = conn.cursor()
	if outString != "":
		cursor.callproc("dbms_output.enable")
	# Execute the query
	cursor.execute(sql)
	# Return dbms_output if outstring
	if(outString != ""):
		chunk_size = 100
		output = cursor.arrayvar(str, chunk_size)
		lineCount = cursor.var(int)
		lineCount.setvalue(0, chunk_size)

		# fetch the text that was added by PL/SQL
		while True:
			cursor.callproc("dbms_output.get_lines",(output,lineCount))
			numLines = lineCount.getvalue()
			lines = output.getvalue()[:numLines]
			return lines
	if cursor.description == None:
		return
	#store resultant header into a list
	cols = [row[0] for row in cursor.description]
	if(toFile != ""):
		ifh = open(toFile,"w")
		ifh.write("\t".join(cols) + "\n")
		for row in cursor:
			outEntry = []
			for val in row:
				if val is None:
					outEntry.append("")
				else:
					outEntry.append(str(val))
			ifh.write("\t".join(outEntry) + "\n")
		ifh.close()
		return
	else:
		#dataContainer
		data = []
		# Loop over the result set and push to data
		for row in cursor:
			data.append(list(row))
		df = pd.DataFrame(data,columns=cols)
		return df

def normalizeDate(date,yyyymmdd="",underscore=""):
	date = str(date).strip()
	dateTup = ()
	if(re.search("^\d{8}$",date)):
		dateTup = (date[0:4],date[4:6],date[6:8])
	elif(re.search("^\d{4}_\d{2}_\d{2}$",date)):
		dateTup = (date[0:4],date[5:7],date[8:10])
	elif(re.search("^\d{2}\/\d{2}\/\d{4}$",date)):
		dateTup = (date[6:10],date[0:2],date[3:5])
	elif(re.search("^\d{1}\/\d{2}\/\d{4}$",date)):
		dateTup = (date[5:9],'0' + date[0:1],date[2:4])
	elif(re.search("^\d{2}\/\d{1}\/\d{4}$",date)):
		dateTup = (date[5:9],date[0:2],'0' + date[3:4])
	elif(re.search("^\d{1}\/\d{1}\/\d{4}$",date)):
		dateTup = (date[4:8],'0' + date[0:1],'0' + date[2:3])
	if(underscore != ""):
		return("_".join(dateTup))
	elif(yyyymmdd != ""):
		return("".join(dateTup))
	else:
		dateList = [dateTup[1],dateTup[2],dateTup[0]]
		return("/".join(dateList))

#Input:     header=>header you want to create an index mapping for
#Optional:  delimiter=>a character to split on
#Function:  reads in a deliminated header and creates a dict of Field=>index key=>value pairs
#Output: returns a dict
def getHeaders(header,delimiter="\t"):
	headerArr = header.split(delimiter)
	hDict = {key: i for i, key in enumerate(headerArr)}
	return hDict

#Takes a tab file location and a list of fields in said file.
#Outputs only those fields to outFile
def subsetTab(tabFile,fields,outFile,fieldMap=None):
	ifh = open(tabFile,"r")
	header = ifh.readline().strip()
	hDict = getHeaders(header=header)
	#verify all values in 'fields' exist in hDict
	finalFields = []
	for field in fields:
		if not field in hDict.keys(): exit("requested field: " + field + " not found in " + tabFile)
		if fieldMap is not None:
			if field in fieldMap.keys():
				finalFields.append(fieldMap[field])
			else:
				finalFields.append(field)
		else:
			finalFields.append(field)
	ofh = open(outFile,"w")
	ofh.write("\t".join(finalFields) + "\n")
	for line in ifh:
		entry = line.split("\t")
		outEntry = []
		for field in fields:
			outEntry.append(entry[hDict[field]])
		ofh.write("\t".join(outEntry))
	ifh.close()
	ofh.close()
	return

#Takes a tab file and uploads it to Oracle with given Instance, User, and Password information,
#Naming it 'tabName'. Delimiter of file can be specified. Tab is default
def loadTable(tabFile,oraInst,oraUser,oraPass,tabName,delim="\t"):
	tabDF = pd.read_csv(tabFile,sep=delim,dtype=str)
	tabDF.fillna('',inplace=True)
	
	conn = cxo.connect(oraUser,oraPass,oraInst)
	cur = conn.cursor()
	#drop table if it exists
	cur.execute("Begin execute immediate 'drop table " + tabName + "'; exception when others then null; end;")
	#create table
	createSql = "Create table " + tabName + " ("
	for x in tabDF.columns:
		fieldType = "varchar(255)"
		createSql += "\n\t" + x + " " + fieldType + ","
	createSql = re.sub(",$",")",createSql)
	cur.execute(createSql)
	#print(createSql + "\n")
	
	#populate newly created table
	rows = [tuple(x) for x in tabDF.values]
	insertSql = "Insert Into " + tabName + "("
	for x in tabDF.columns:
		insertSql += "\n\t" + x + ","
	insertSql = re.sub(",$",")",insertSql)
	insertSql += "\nValues ("
	for i in range(len(tabDF.columns)):
		insertSql += ":" + str(i+1) + ","
	insertSql = re.sub(",$",")",insertSql)
	#print(insertSql + "\n")
	cur.prepare(insertSql)
	cur.executemany(None,rows)
	conn.commit()
	cur.close()
	conn.close()
	del tabDF

def dropTable(oraInst,oraUser,oraPass,tabName):
	conn = cxo.connect(oraUser,oraPass,oraInst)
	cur = conn.cursor()
	cur.execute("Begin execute immediate 'drop table " + tabName + "'; exception when others then null; end;")

def getProfileData(listFile,vintage,joinType="left",toFile=""):
	vintage = normalizeDate(date=vintage,yyyymmdd="Y")
	#print(listFile)
	#print(vintage)
	oraInst = "PLDWH2DBR"
	oraUser = "claims_usr"
	oraPass = oraUser + "123"
	oraTable = "MY_TABLE_" + str(random.randrange(100000))
	if not os.path.isfile(listFile):
		exit("Cannot open " + listFile)
	header = bt.getoutput("head -n1 " + listFile)
	#print(oraTable)
	#print(header)
	profSql = None
	loadTable(tabFile=listFile,oraInst=oraInst,oraUser=oraUser,oraPass=oraPass,tabName=oraTable)
	if(header == "HMS_PIID"):
		profSql =  "select base.hms_piid,\n\
									pract.first,\n\
									pract.middle,\n\
									pract.last,\n\
									pract.suffix,\n\
									pract.cred,\n\
									pract.practitioner_type,\n\
									pract.hms_spec1,\n\
									pract.hms_spec2,\n\
									pract.npi,\n\
									addr.firm_name,\n\
									addr.address1,\n\
									addr.address2,\n\
									addr.city,\n\
									addr.state,\n\
									addr.zip,\n\
									addr.zip4,\n\
									addr.latitude,\n\
									addr.longitude,\n\
									addr.phone1,\n\
									addr.phone2,\n\
									addr.fax1,\n\
									addr.fax2,\n\
									addr.fips5_code,\n\
									addr.cbsa_code,\n\
									pract.year_born,\n\
									pract.gender,\n\
									pract.school_name,\n\
									pract.grad_year,\n\
									pract.npi_taxonomy\n\
									from " + oraTable + " base\n" +\
									joinType + " join profiledata.practitioners_view pract on base.hms_piid = pract.hms_piid and pract.vintage_num = '" + vintage + "'\n" +\
									joinType + " join profiledata.practitioner_addresses_view addr on base.hms_piid = addr.hms_piid and addr.vintage_num = '" + vintage + "'";
	elif(header == "HMS_POID"):
		profSql = "select base.hms_poid,\n\
									addr.org_name as ORGNAME,\n\
									org.facility_type_code as FACTYPE,\n\
									org.orgtype_desc as ORGTYPE,\n\
									addr.address1,\n\
									addr.address2,\n\
									addr.city,\n\
									addr.state,\n\
									addr.zip,\n\
									addr.zip4,\n\
									addr.phone1,\n\
									addr.phone2,\n\
									addr.fax1,\n\
									addr.fax2,\n\
									addr.longitude,\n\
									addr.latitude,\n\
									org.gp_spec1,\n\
									org.gp_spec2,\n\
									org.npi,\n\
									addr.fips5_code as FIPS,\n\
									ppx1.value as POS1,\n\
									ppx2.value as POS2,\n\
									ppx3.value as POS3\n\
									from " + oraTable + " base\n" +\
									joinType + " join profiledata.organizations_view org on base.hms_poid = org.hms_poid and org.vintage_num = '" + vintage + "'\n" +\
									joinType + " join profiledata.organization_addresses_view addr on base.hms_poid = addr.hms_poid and addr.vintage_num = '" + vintage + "'\n\
									left join (select * from profiledata.poid_identifiers_view where rank = '1' and id_type = 'POS' and vintage_num = '" + vintage + "') ppx1 on base.hms_poid = ppx1.hms_poid\n\
									left join (select * from profiledata.poid_identifiers_view where rank = '2' and id_type = 'POS' and vintage_num = '" + vintage + "') ppx2 on base.hms_poid = ppx2.hms_poid\n\
									left join (select * from profiledata.poid_identifiers_view where rank = '3' and id_type = 'POS' and vintage_num = '" + vintage + "') ppx3 on base.hms_poid = ppx3.hms_poid"
	else:
		dropTable(oraInst=oraInst,oraUser=oraUser,oraPass=oraPass,tabName=oraTable)
		exit("Unrecognized header in listFile: " + header)
	if(toFile != ""):
		getOracleSql(oraUser=oraUser,oraPass=oraPass,oraInst=oraInst,sql=profSql,toFile=toFile)
		dropTable(oraInst=oraInst,oraUser=oraUser,oraPass=oraPass,tabName=oraTable)
		return
	else:
		returnDF = getOracleSql(oraUser=oraUser,oraPass=oraPass,oraInst=oraInst,sql=profSql)
		if(header == "HMS_PIID"):
			for field in "GRAD_YEAR","YEAR_BORN":
				returnDF[field] = (
					returnDF[field].fillna(0)
					.astype(int)
					.astype(object)
					.where(returnDF[field].notnull())
				)
		dropTable(oraInst=oraInst,oraUser=oraUser,oraPass=oraPass,tabName=oraTable)
		return(returnDF)

def convertCsv(csvFile,outFile,sep="\t"):
	validSeps = {"\t","|"}
	if sep not in validSeps:
		exit("delim: " + sep + " not valid. Must be \\t or |")
	ifh = open(csvFile,"r")
	ofh = open(outFile,"w")
	for line in ifh:
		line.rstrip()
		quoted = False
		for char in line:
			if char == "\"":
				quoted = not quoted
			elif char == ",":
				if quoted:
					ofh.write(char)
				else:
					ofh.write(sep)
			else:
				ofh.write(char)
		ofh.write("\n")
	ifh.close()
	ofh.close()

def sendEmail(subject,message,email=""):
	username = pwd.getpwuid(os.getuid())[0]
	oraUser = "claims_usr";
	oraPass = "claims_usr123";
	oraInstance = "PLDWH2DBR";
	sql = "select * from claims_usr.champs_group";
	cdf = getOracleSql(oraInstance,oraUser,oraPass,sql)
	#print(cdf)
	if email == "":
		try:
			email = cdf[cdf["HMS_USERNAME"] == username]["LN_EMAIL"].item()
		except:
			subject = "Unknown LN Email";
			message = "User: " + username + " attempted to send an email to self in code " + os.path.basename(__file__) + " but no mapping was found in champs_group. Please add this user to the champs_group table\n";
			email = cdf[cdf["HMS_USERNAME"] == "ssiu"]["LN_EMAIL"].item()
	#print(email,subject,message)
	# boca migration requires new smtp server not localhost
	server = (
		"appmail.risk.regn.net" if socket.gethostname()[:3] == "bct" else "localhost"
	)
	msg = """From: """ + email + """
		To: """ + email + """
		Subject: """ + subject + """\n\n"""
	msg += message
	errors = None
	try:
		s = smtplib.SMTP(server)
		s.sendmail(email,email,msg)
	except:
		print("Email attempt to: " + email + " failed.\nMsg: " + msg)

def getRxPayermix(piidList,vintage,outFile="",exclude=[]):
	RxPayermix(
		vintage=dtParse.parse(vintage),
		piid_list=piidList,
		report_counts=False,
		report_payers=True,
		pivot_categories=False,
		round_pct_digits=1,
		include={v for v in PayerType},
		exclude=exclude,
		report_names=False,
	).run()
	if(outFile):
		os.system("mv payermix.txt " + outFile)
	return True

def atoi(text):
   return int(text) if text.isdigit() else text

#usage:
#list.sort(key=mf.naturalSort) || newList = sorted(list,key=mf.naturalSort)
#Assumes list is an array of strings
def naturalSort(text):
	return [atoi(c) for c in re.split(r'(\d+)',text)]
	

