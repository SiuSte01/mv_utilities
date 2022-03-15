#!/usr/bin/env python3

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
import pickle
import shutil

logger = logging.getLogger(__name__)
memoryHash = {}

def main():
	#tqdmLoop()
	parser = argparse.ArgumentParser(description="Generate reports from timeAggr data")
	parser.add_argument("-serialFile", "--serialFile")
	parser.add_argument("-startDate", "--startDate")
	parser.add_argument("-endDate", "--endDate")
	parser.add_argument("-reportType", "--reportType",choices=["act","kat","both"],default="both")
	
	args = parser.parse_args()
	#print(args)
	serRoot = "/vol/cs/clientprojects/MarketViewTracking/timeAggr/changeLog"
	serFile = serRoot + "/latestSerial.txt"
	if args.serialFile:
		serFile = serRoot + "/serials/" + args.serialFile
	#print(serFile)
	startDate = args.startDate or ""
	endDate = args.endDate or ""
	repType = args.reportType
	if startDate:
		startDate = mf.normalizeDate(date=startDate,yyyymmdd="y")
	if endDate:
		endDate = mf.normalizeDate(date=endDate,yyyymmdd="y")
	if startDate and endDate and endDate < startDate:
		exit("endDate must be later than startDate")
	global memoryHash
	memoryHash = pickle.load(open(serFile,"rb"))
	#print(yaml.dump(memoryHash))
	if(repType == "act"):
		buildActReport(startDate,endDate)
	elif(repType == "kat"):
		buildKatReport(startDate,endDate)
	else:
		buildActReport(startDate,endDate)
		buildKatReport(startDate,endDate)

def buildActReport(startDate,endDate):
	print("Generating ActiTime Reports...",end="")
	global memoryHash
	actHash = {}
	reportableEmps = {
		"Bertel,Evan",
		"Charlesworth,Allaire",
		"Edgar-Nielsen,James",
		"Eisenberg,Emily",
		"Jones,Molli",
		"Kinzer,Kathryn",
		"Otterbein,Matthew",
		"Sisti,Jason",
		"Stephano,Rachael",
		"Taylor,Karalee"
	}
	for emp in sorted(memoryHash["peopleHash"]):
		toEmp = emp
		#set toEmp to Molli if technical staff
		if emp == "Jones,Molli" or emp not in reportableEmps:
			toEmp = "Jones,Molli"
			#print(emp + " - " + toEmp)
		entries = memoryHash["peopleHash"][emp]["workEntries"]
		for entry in entries:
			date = entries[entry]["date"]
			#if timeFrame is specified, make sure entry falls within it, otherwise, ignore
			dateAcceptable = True
			if startDate and date < startDate:
				dateAcceptable = False
			elif endDate and date > endDate:
				dateAcceptable = False
			if not dateAcceptable:
				continue
			cust = entries[entry]["customer"]
			delComp = entries[entry]["deliverableComplete"]
			hours = entries[entry]["hours"]
			nonStandardProc = entries[entry]["nonStandardProc"]
			task = entries[entry]["task"]
			description = ""
			if task.lower() == "production deliverable" or task.lower() == "production support":
				task = "Production"
				description = "Deliverable" if task.lower() == "production deliverable" else "Support"
			typeOfWork = entries[entry]["workTypes"]
			#print(",".join(str(e) for e in [emp,toEmp,date,cust,delComp,hours,nonStandardProc,task]))
			#first time encountering a to Employee, create employee with a fresh record
			#unique on Customer,Task,Deadline
			entryKey = ''.join([cust,task,date])
			if not toEmp in actHash:
				actHash[toEmp] = {
					entryKey: {
						"customer": cust,
						"product": "Claims Data Products (PxDx)",
						"task": task,
						"description": description,
						"typeOfWork": typeOfWork,
						"deadline": mf.normalizeDate(date),
						"estimate": hours
					}
				}
			#first time encountering an entry for a previously defined to Employee, add a fresh record
			elif not entryKey in actHash[toEmp]:
				actHash[toEmp][entryKey] = {
					"customer": cust,
					"product": "Claims Data Products (PxDx)",
					"task": task,
					"description": description,
					"typeOfWork": typeOfWork,
					"deadline": mf.normalizeDate(date),
					"estimate": hours
				}
			#found a previous entryKey, update it
			else:
				if description == "Deliverable":
					actHash[toEmp][entryKey]["description"] = description
				for workType in typeOfWork:
					actHash[toEmp][entryKey]["typeOfWork"].add(workType)
				actHash[toEmp][entryKey]["estimate"] += hours
			#print(yaml.dump(memoryHash["peopleHash"][emp]["workEntries"]))
	actOut = "actReports"
	try:
		shutil.rmtree(actOut)
	except:
		pass
	try:
		os.makedirs(actOut)
	except:
		pass
	wofh = open(actOut + "/reportWindow.txt",'w')
	wofh.write("startDate: " + startDate + "\n")
	wofh.write("endDate: " + endDate + "\n")
	wofh.close()
	for emp in actHash:
		empUnderscore = re.sub(',','_',emp)
		aofh = open(actOut + "/" + empUnderscore + "_ActiTime_Report.tab",'w')
		aofh.write('\t'.join(['CUSTOMER','PRODUCT','TASK','DESCRIPTION','TYPE_OF_WORK','DEADLINE','ESTIMATE'])  + "\n")
		for entry in actHash[emp]:
			outEntry = []
			for val in ['customer','product','task','description']:
				outEntry.append(actHash[emp][entry][val])
			outEntry.append(','.join(actHash[emp][entry]["typeOfWork"]))
			for val in ['deadline','estimate']:
				outEntry.append(actHash[emp][entry][val])
			aofh.write('\t'.join(str(v) for v in outEntry) + "\n")
		aofh.close()
	print("done")

def buildKatReport(startDate,endDate):
	print("Generating Kat Reports...",end="")
	global memoryHash
	katHash = {
		"deliverablesComplete": {},
		"hoursSpent": {}
	}
	deliverableEmps = {
		"Bertel,Evan",
		"Charlesworth,Allaire",
		"Edgar-Nielsen,James",
		"Eisenberg,Emily",
		"Kinzer,Kathryn",
		"Otterbein,Matthew",
		"Sisti,Jason",
		"Stephano,Rachael",
		"Taylor,Karalee"
	}
	#generate output directory and open file handles
	katOut = "katReports"
	try:
		shutil.rmtree(katOut)
	except:
		pass
	try:
		os.makedirs(katOut)
	except:
		pass
	rofh = open(katOut + "/recordLevelReport.tab",'w')
	rofh.write("\t".join(["USER","DATE","CUSTOMER","TASK","HOURS","DELIVERABLE_COMPLETE","NON_STANDARD_PROC","WORK_TYPES"]) + "\n")
	for emp in sorted(memoryHash["peopleHash"]):
		#print(emp)
		entries = memoryHash["peopleHash"][emp]["workEntries"]
		for entry in entries:
			date = entries[entry]["date"]
			#if timeFrame is specified, make sure entry falls within it, otherwise, ignore
			dateAcceptable = True
			if startDate and date < startDate:
				dateAcceptable = False
			elif endDate and date > endDate:
				dateAcceptable = False
			if not dateAcceptable:
				continue
			cust = entries[entry]["customer"]
			delComp = entries[entry]["deliverableComplete"]
			hours = entries[entry]["hours"]
			nonStandardProc = entries[entry]["nonStandardProc"]
			task = entries[entry]["task"]
			workTypes = entries[entry]["workTypes"]
			#add deliverables complete
			delCompKey = cust + task
			if not delCompKey in katHash["deliverablesComplete"]:
				katHash["deliverablesComplete"][delCompKey] = {
					"customer": cust,
					"task": task,
					"nonStandardProc": nonStandardProc,
					"completionCount": 0,
					"deliveryHours": 0,
					"techHours": 0,
					"earliestDate": date,
					"latestDate": date,
					"workTypes": workTypes
				}
				if delComp == "Y":
					katHash["deliverablesComplete"][delCompKey]["completionCount"] += 1
			else:
				if nonStandardProc == "Y":
					katHash["deliverablesComplete"][delCompKey]["nonStandardProc"] = nonStandardProc
				if delComp == "Y":
					katHash["deliverablesComplete"][delCompKey]["completionCount"] += 1
				if date < katHash["deliverablesComplete"][delCompKey]["earliestDate"]:
					katHash["deliverablesComplete"][delCompKey]["earliestDate"] = date
				if date > katHash["deliverablesComplete"][delCompKey]["latestDate"]:
					katHash["deliverablesComplete"][delCompKey]["latestDate"] = date
				for workType in workTypes:
					katHash["deliverablesComplete"][delCompKey]["workTypes"].add(workType)
			if emp in deliverableEmps:
				katHash["deliverablesComplete"][delCompKey]["deliveryHours"] += hours
			else:
				katHash["deliverablesComplete"][delCompKey]["techHours"] += hours
			#add hours spent
			hoursSpentKey = task
			if not hoursSpentKey in katHash["hoursSpent"]:
				katHash["hoursSpent"][hoursSpentKey] = {
					"task": task,
					"hoursSpent": hours
				}
			else:
				katHash["hoursSpent"][hoursSpentKey]["hoursSpent"] += hours
			#add record to RLR file
			rofh.write("\t".join(str(v) for v in [emp,date,cust,task,hours,delComp,nonStandardProc,','.join(workTypes)]) + "\n")
			#print(yaml.dump(memoryHash["peopleHash"][emp]["workEntries"][entry]))
	rofh.close()
	#print(yaml.dump(katHash))
	wofh = open(katOut + "/reportWindow.txt",'w')
	wofh.write("startDate: " + startDate + "\n")
	wofh.write("endDate: " + endDate + "\n")
	wofh.close()
	#dofh = open(katOut + "/deliverablesComplete.tab",'w')
	#dofh.write("\t".join(["CUSTOMER","TASK","DELIVERABLES_COMPLETE"]) + "\n")
	hofh = open(katOut + "/hoursSpent.tab",'w')
	hofh.write("\t".join(["TASK","HOURS"]) + "\n")
	cofh = open(katOut + "/customerLevelReport.tab",'w')
	cofh.write("\t".join(["CUSTOMER","TASK","NON_STANDARD_PROC","DELIVERABLES_COMPLETE","DELIVERY_HOURS","TECH_HOURS","EARLIEST_DATE","LATEST_DATE","WORK_TYPES"]) + "\n")
	for delComp in sorted(katHash["deliverablesComplete"]):
		cust = katHash["deliverablesComplete"][delComp]["customer"]
		task = katHash["deliverablesComplete"][delComp]["task"]
		nonStandardProc = katHash["deliverablesComplete"][delComp]["nonStandardProc"]
		completionCount = katHash["deliverablesComplete"][delComp]["completionCount"]
		delHours = katHash["deliverablesComplete"][delComp]["deliveryHours"]
		techHours = katHash["deliverablesComplete"][delComp]["techHours"]
		earlyDate = katHash["deliverablesComplete"][delComp]["earliestDate"]
		lateDate = katHash["deliverablesComplete"][delComp]["latestDate"]
		workTypes = katHash["deliverablesComplete"][delComp]["workTypes"]
		cofh.write("\t".join(str(v) for v in [cust,task,nonStandardProc,completionCount,delHours,techHours,earlyDate,lateDate,','.join(workTypes)]) + "\n")
	for hoursSpent in sorted(katHash["hoursSpent"]):
		task  = katHash["hoursSpent"][hoursSpent]["task"]
		hoursSpent  = katHash["hoursSpent"][hoursSpent]["hoursSpent"]
		hofh.write("\t".join(str(v) for v in [task,hoursSpent]) + "\n")
	cofh.close()
	hofh.close()
	print("done")

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
