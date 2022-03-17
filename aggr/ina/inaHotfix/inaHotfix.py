#!/opt/local/marketview/conda/1/envs/master/bin/python

from dateutil.parser import parse as dtParse
import logging
import argparse
import os,sys
import warnings
import json
import yaml
import pandas as pd
import numpy as np
from contextlib import closing
import itertools, collections
from tqdm import tqdm
import time
import re
from mvUtil import miscfunctions as mf

logger = logging.getLogger(__name__)

outDir = "hotfixedINAs"
workDir = "work"
#generate dict of INAs and rule sets to perform
rules = {}
#inaName->inaDir Map
inaMap = {}

pd.set_option("display.max_columns",None)

def main():
	#tqdmLoop()
	parser = argparse.ArgumentParser(description="Read in an input.tab.")
	parser.add_argument("-inputTab", "--inputTab",required=True)
	
	args = parser.parse_args()
	#print(args)
	#print (args.inputTab)
	for d in outDir,workDir:
		if not os.path.exists(d):
			os.mkdir(d)
	errList = []
	eofh = open(workDir + "/errors.txt","w")
	eofh.write("Errors, if there are any\n")
	
	inputDF = pd.read_csv(args.inputTab,sep="\t")
	inputDF = inputDF.fillna("")
	
	sys.stdout.write("Generating rules...")
	for i,r in inputDF.iterrows():
		inaDir = r["INA_DIR"]
		networks = r["NETWORKS"]
		qtd = str(r["QTRS_TO_DAYS"]).upper()
		direct = str(r["DIRECTIONALITY"]).upper()
		dxCoh = str(r["DX_COHORT"]).upper()
		cohDx = str(r["COHORT_DX"]).upper()
		pxCoh = str(r["PX_COHORT"]).upper()
		cohPx = str(r["COHORT_PX"]).upper()
		dxc = ""
		pxc = ""
		if(dxCoh.upper() == "Y"):
			dxc = "D"
		elif(cohDx.upper() == "Y"):
			dxc = "C"
		if(pxCoh.upper() == "Y"):
			pxc = "P"
		elif(cohPx.upper() == "Y"):
			pxc = "C"
		#print(i)
		#print(r)
		#print(inaDir,networks,qtd,direct,dxCoh,cohDx,pxCoh,cohPx)
		if(dxCoh != "" and cohDx != ""):
			exit("DX_COHORT and COHORT_DX cannot both be set for: " + inaDir)
		if(pxCoh != "" and cohPx != ""):
			exit("PX_COHORT and COHORT_PX cannot both be set for: " + inaDir)
		#getBasename
		inaName = os.path.basename(inaDir)
		#print("basename: " + inaName)
		#Create ruleset for reserved INA_NAME GLOBAL
		if inaDir == "GLOBAL":
			rules[inaName] = {}
			rules[inaName]["QTRS_TO_DAYS"] = qtd
			rules[inaName]["DIRECTIONALITY"] = direct
			rules[inaName]["DXC"] = dxc
			rules[inaName]["PXC"] = pxc
		else:
			if networks == "":
				networks = "ALL"
			networkArr = networks.split(",")
			#print(networkArr)
			#define baseName->inaDir if not defined
			if inaName not in inaMap.keys():
				inaMap[inaName] = inaDir
				rules[inaName] = {}
				for net in networkArr:
					#print("processing: " + net)
					rules[inaName][net] = {}
					rules[inaName]["INA_DIR"] = inaDir
					rules[inaName][net]["QTRS_TO_DAYS"] = qtd
					rules[inaName][net]["DIRECTIONALITY"] = direct
					rules[inaName][net]["DXC"] = dxc
					rules[inaName][net]["PXC"] = pxc
			#otherwise check if baseName->inaDir matches currently existing one.
			else:
				baseName = getBaseName(inaName=inaName,inaDir=inaDir,inaMap=inaMap)
				#print("baseName is: " + baseName)
				if baseName not in inaMap.keys():
					inaMap[baseName] = inaDir
					rules[baseName] = {}
				for net in networkArr:
					#print("processing: " + net)
					rules[baseName][net] = {}
					rules[baseName]["INA_DIR"] = inaDir
					rules[baseName][net]["QTRS_TO_DAYS"] = qtd
					rules[baseName][net]["DIRECTIONALITY"] = direct
					rules[baseName][net]["DXC"] = dxc
					rules[baseName][net]["PXC"] = pxc
				#inaName is bad. get 
			#add if so, create new basename otherwise
	print("done")
#	print("EYYYYOOOO")
#	print(yaml.dump(rules))
#	print(yaml.dump(inaMap))
	#open filehandle for mapFile
	mofh = open(outDir + "/" + "inaMap.tab","w")
	mofh.write("INA_NAME\tPATH\n")
	for inaName in inaMap:
		inaDir = rules[inaName]["INA_DIR"]
		mofh.write("\t".join((inaName,inaDir)) + "\n")
		sys.stdout.write("Producing new INA: " + inaName + "...")
		#print(inaName,inaDir)
		if not os.path.exists(inaDir):
			eofh.write("Path not found: " + inaName)
			continue
		if not os.path.exists(outDir + "/" + inaName):
			os.mkdir(outDir + "/" + inaName)
			os.mkdir(outDir + "/" + inaName + "/config")
		#copy config dir
		configDir = inaDir + "/config"
		setVars = copySettingsFile(configDir=configDir,jobName=inaName)
		convertNetworkConfig(configDir=configDir,jobName=inaName)
		copyRemainingFiles(setVars=setVars,configDir=configDir,jobName=inaName)
		print("done")
#	print(yaml.dump(inaMap))
	mofh.close()
	os.system("chmod 777 -R .")

def copySettingsFile(configDir,jobName):
	settFile = configDir + "/settings.cfg"
	setVars = mf.createSettingDict(settFile)
	setVars.pop('JOB_ID',None)
	#print(setVars)
	mf.writeSettingFile(config=setVars,outFile=outDir + "/" + jobName + "/config/settings.cfg")
	return setVars

def convertNetworkConfig(configDir,jobName):
	netFile = pd.read_csv(
		configDir + "/networkConfigSettings.tab",sep="\t",
		dtype={
			"LINK_DAYS":object,
			"LINK_QTRS":object,
			"DIRECTIONAL_FLAG":object,
			"DEFAULT_GRP":object
			}
		)
	#print(netFile[["NETWORK_NAME","DIRECTIONAL_FLAG"]])
	#print(netFile)
	#exit()
	#print(yaml.dump(rules[jobName]))
	#if there is a global ruleset, ignore all other rules and apply it:
	if "GLOBAL" in rules:
		netFile = netFix(netFile=netFile,ruleSet=rules["GLOBAL"])
	#if there is an all ruleset for the specific INA, ignore all other rules specific to this ina
	elif "ALL" in rules[jobName]:
		netFile = netFix(netFile=netFile,ruleSet=rules[jobName]["ALL"])
	else:
		netFile = netFix(netFile=netFile,ruleSet=rules[jobName],networks="Y")
	rofh = open(outDir + "/" + jobName + "/config/networkConfigSettings.tab","w")
	netHeader = list(mf.qw("NETWORK_NAME CODE_GROUP_NAME1 CODE_GROUP_NAME2 NETWORK_TYPE RELATION_TYPES CODE_GRP1_TYP CODE_GRP1 CODE_GRP2_TYP CODE_GRP2 LINK_DAYS LINK_QTRS PTNT_SEX MAX_PTNT_AGE MIN_PTNT_AGE DIRECTIONAL_FLAG LOOKBACK_FLAG DEFAULT_GRP INCLUDE_NON_DEFAULT_GRP"))
	if "GUID" in netFile:
		netHeader.append("GUID")
	rofh.write("\t".join(netHeader) + "\n")
	netFile.to_csv(outDir + "/" + jobName + "/config/networkConfigSettings.tab",index=False,sep="\t")
	rofh.close()

def copyRemainingFiles(setVars,configDir,jobName):
	csFile = configDir + "/" + setVars["CLAIM_SETTINGS_FILE"][0]
	cgFile = configDir + "/" + setVars["CODE_GROUPS_FILE"][0]
	cgmFile = configDir + "/" + setVars["CODE_GRP_MEMBRS_FILE"][0]
	popFile = configDir + "/population.txt"
	guidFile = configDir + "/guidNetworks.tab"
	for f in csFile,cgFile,cgmFile,popFile,guidFile:
		if(os.path.exists(f)):
			os.system("cp " + f + " " + outDir + "/" + jobName + "/config")

def getBaseName(inaName,inaDir,inaMap,offset=0):
	if offset == 0:
		if inaName not in inaMap.keys():
			return inaName
		elif inaMap[inaName] == inaDir:
			return inaName
		else:
			return getBaseName(inaName=inaName,inaDir=inaDir,inaMap=inaMap,offset=offset+1)
	else:
		if inaName + str(offset) not in inaMap.keys():
			return inaName + str(offset)
		elif inaMap[inaName + str(offset)] == inaDir:
			return inaName + str(offset)
		else:
			return getBaseName(inaName=inaName,inaDir=inaDir,inaMap=inaMap,offset=offset+1)

def netFix(netFile,ruleSet,networks=None):
	#print(ruleSet)
	rQtd = ""
	rDir = ""
	rDxc = ""
	rPxc = ""
	if(networks == None):
		rQtd = ruleSet["QTRS_TO_DAYS"]
		rDir = ruleSet["DIRECTIONALITY"]
		rDxc = ruleSet["DXC"]
		rPxc = ruleSet["PXC"]
	#print("\n")
	#print(rQtd,rDir,rDxc,rPxc)
	#exit()
	for i,r in netFile.iterrows():
		#No ALL rule found, check if rule given for specific network
		if(networks != None):
			netName = r["NETWORK_NAME"]
			if netName in ruleSet:
				rQtd = ruleSet[netName]["QTRS_TO_DAYS"]
				rDir = ruleSet[netName]["DIRECTIONALITY"]
				rDxc = ruleSet[netName]["DXC"]
				rPxc = ruleSet[netName]["PXC"]
			else:
				continue
		#print(r)
		#print("\n")
		#convert link_qtrs to link_days
		if rQtd == "Y" and pd.isnull(r["LINK_DAYS"]):
			netFile.at[i,"LINK_DAYS"] = int(r["LINK_QTRS"]) * 90
			netFile.at[i,"LINK_QTRS"] = np.nan
		#explicit day count specified, set it and null link_qtrs
		elif rQtd != "":
			netFile.at[i,"LINK_DAYS"] = rQtd
			netFile.at[i,"LINK_QTRS"] = np.nan
		#set directionality if applicable
		if rDir == "Y":
			netFile.at[i,"DIRECTIONAL_FLAG"] = "1"
		netType = r["NETWORK_TYPE"]
		#set cohort sides if applicable
		if(netType == "COHORT"):
			cg1 = r["CODE_GRP1"]
			cg2 = r["CODE_GRP2"]
			cgn1 = r["CODE_GROUP_NAME1"]
			cgn2 = r["CODE_GROUP_NAME2"]
			cg1Typ = r["CODE_GRP1_TYP"]
			cg2Typ = r["CODE_GRP2_TYP"]
			#force cohort on left side for easier processing
			if(cg2Typ == "COHORT"):
				cg1 = r["CODE_GRP2"]
				cg2 = r["CODE_GRP1"]
				cgn1 = r["CODE_GROUP_NAME2"]
				cgn2 = r["CODE_GROUP_NAME1"]
				cg1Typ = r["CODE_GRP2_TYP"]
				cg2Typ = r["CODE_GRP1_TYP"]
			if rDxc != "" and cg2Typ == "DX":
				if(rDxc == "D"):
					netFile.at[i,"CODE_GRP1"] = cg2
					netFile.at[i,"CODE_GRP2"] = cg1
					netFile.at[i,"CODE_GROUP_NAME1"] = cgn2
					netFile.at[i,"CODE_GROUP_NAME2"] = cgn1
					netFile.at[i,"CODE_GRP1_TYP"] = cg2Typ
					netFile.at[i,"CODE_GRP2_TYP"] = cg1Typ
					netFile.at[i,"LOOKBACK_FLAG"] = ""
					netFile.at[i,"DEFAULT_GRP"] = ""
					netFile.at[i,"INCLUDE_NON_DEFAULT_GRP"] = "N"
				elif(rDxc == "C"):
					netFile.at[i,"CODE_GRP1"] = cg1
					netFile.at[i,"CODE_GRP2"] = cg2
					netFile.at[i,"CODE_GROUP_NAME1"] = cgn1
					netFile.at[i,"CODE_GROUP_NAME2"] = cgn2
					netFile.at[i,"CODE_GRP1_TYP"] = cg1Typ
					netFile.at[i,"CODE_GRP2_TYP"] = cg2Typ
					netFile.at[i,"LOOKBACK_FLAG"] = "Y"
					netFile.at[i,"DEFAULT_GRP"] = ""
					netFile.at[i,"INCLUDE_NON_DEFAULT_GRP"] = "N"
			if rPxc != "" and cg2Typ == "PX":
				if(rPxc == "P"):
					netFile.at[i,"CODE_GRP1"] = cg2
					netFile.at[i,"CODE_GRP2"] = cg1
					netFile.at[i,"CODE_GROUP_NAME1"] = cgn2
					netFile.at[i,"CODE_GROUP_NAME2"] = cgn1
					netFile.at[i,"CODE_GRP1_TYP"] = cg2Typ
					netFile.at[i,"CODE_GRP2_TYP"] = cg1Typ
					netFile.at[i,"LOOKBACK_FLAG"] = ""
					netFile.at[i,"DEFAULT_GRP"] = ""
					netFile.at[i,"INCLUDE_NON_DEFAULT_GRP"] = "N"
				elif(rPxc == "C"):
					netFile.at[i,"CODE_GRP1"] = cg1
					netFile.at[i,"CODE_GRP2"] = cg2
					netFile.at[i,"CODE_GROUP_NAME1"] = cgn1
					netFile.at[i,"CODE_GROUP_NAME2"] = cgn2
					netFile.at[i,"CODE_GRP1_TYP"] = cg1Typ
					netFile.at[i,"CODE_GRP2_TYP"] = cg2Typ
					netFile.at[i,"LOOKBACK_FLAG"] = "Y"
					netFile.at[i,"DEFAULT_GRP"] = cg2
					netFile.at[i,"INCLUDE_NON_DEFAULT_GRP"] = "Y"
		#print(r)
	return netFile

def tqdmLoop():
	for i in tqdm(range(0,100),desc="tqdm sample"):
		sleep(.5)

if __name__ == '__main__':
	startTime = time.time()
	main()
	endTime = time.time()
	hours, rem = divmod(endTime-startTime, 3600)
	minutes, seconds = divmod(rem, 60)
	print("Program:\n\t" + __file__ + "\nRun Time: {:0>2}:{:0>2}:{:05.2f}".format(int(hours),int(minutes),seconds))
