#!/opt/local/marketview/conda/1/envs/master/bin/python

from dateutil.parser import parse as dtParse
import logging
import argparse
import os,sys
import subprocess as sbp
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

def main():
	#tqdmLoop()
	parser = argparse.ArgumentParser(description="Read in a config file.")
	parser.add_argument("-slQtr", "--slQtr",required=True)
	parser.add_argument("-injectionMap","--injectionMap",default="mapping.tab")
	
	args = parser.parse_args()
	#print(args)
	#print (args.slQtr)
	
	slRt = "/vol/cs/clientprojects/ServiceLines/" + args.slQtr + "/Master/PxDx"
	mpFile = args.injectionMap
	#print(slRt)
	#print(mpFile)
	if not os.path.exists(mpFile):
		exit("injectionMap not found: " + mpFile)
	mpDF = pd.read_csv(mpFile,sep="\t")
	#print(mpDF)
	mpDict = {}
	sslSkip = set()
	outDir = "PxDx"
	if not os.path.exists(outDir):
		os.mkdir(outDir)
	#convert DF to a json
	for i,row in mpDF.iterrows():
		cg = row['CODE_GROUP']
		sl = row['SL_DIR']
		ssl = row['SSL_DIR']
		sslSkip.add(ssl)
		#print(",".join([cg,sl,ssl]))
		if not sl in mpDict.keys():
			mpDict[sl] = {}
		if not ssl in mpDict[sl].keys():
			mpDict[sl][ssl] = {}
		mpDict[sl][ssl][cg] = cg
	#print(yaml.dump(mpDict))
	#exit()
	#parse through mpDict and perform injection
	#counter = 0
	for sl in mpDict:
		#if counter > 0:
		#	continue
		#counter += 0
		print("Building Injected SL: " + sl)
		if not os.path.exists(outDir + "/" + sl):
			os.system("cp -r " + slRt + "/" + sl + " " + outDir)
		#files to update: codeGroupMembers.tab codeGroupRules.tab codeGroups.tab jobVendorSettings.tab 
		newSl = outDir + "/" + sl
		cgmFile = newSl + "/config/codeGroupMembers.tab"
		cgrFile = newSl + "/config/codeGroupRules.tab"
		cgFile = newSl + "/config/codeGroups.tab"
		jvsFile = newSl + "/config/jobVendorSettings.tab"
		slCgm = pd.read_csv(cgmFile,sep="\t")
		slCgr = pd.read_csv(cgrFile,sep="\t")
		slCg = pd.read_csv(cgFile,sep="\t")
		slJvs = pd.read_csv(jvsFile,sep="\t")
		offset = slCg["CODE_GROUP_ID"].max()
		#print(slCg)
		#print(offset)
		for ssl in mpDict[sl]:
			print("\tInjecting from SSL: " + ssl)
			#print ssl's directories just for funzies
#			for fl in os.listdir(slRt + "/" + ssl):
#				if(os.path.isdir(slRt + "/" + ssl + "/" + fl)):
#					print("\t\t" + fl)
			oldSsl = slRt + "/" + ssl
			sslCgmFile = oldSsl + "/config/codeGroupMembers.tab"
			sslCgrFile = oldSsl + "/config/codeGroupRules.tab"
			sslCgFile = oldSsl + "/config/codeGroups.tab"
			sslJvsFile = oldSsl + "/config/jobVendorSettings.tab"
			sslCgm = pd.read_csv(sslCgmFile,sep="\t")
			sslCgr = pd.read_csv(sslCgrFile,sep="\t")
			sslCg = pd.read_csv(sslCgFile,sep="\t")
			sslJvs = pd.read_csv(sslJvsFile,sep="\t")
			for i,row in sslCgr.iterrows():
				sslCgr.loc[i,"CODE_GROUP1_ID"] = sslCgr.loc[i,"CODE_GROUP1_ID"] + offset
			for i,row in sslCg.iterrows():
				sslCg.loc[i,"CODE_GROUP_ID"] = sslCg.loc[i,"CODE_GROUP_ID"] + offset
			#print(sslCgr)
			#print(sslCg)
			offset = sslCg["CODE_GROUP_ID"].max()
#			for x in (sslCgm,sslCgr,sslCg,sslJvsFile):
#				print(x)
			for cg in mpDict[sl][ssl]:
				print("\t\tBuckets that utilize code group: " + cg)
				#print(sslCgm.loc[sslCgm["CODE_GROUP_NAME"] == cg])
				slCgm = slCgm.append(sslCgm.loc[sslCgm["CODE_GROUP_NAME"] == cg])
				#print(sslCgr.loc[sslCgr["CODE_GROUP1"] == cg])
				slCgr = slCgr.append(sslCgr.loc[sslCgr["CODE_GROUP1"] == cg])
				#print(sslCg.loc[sslCg["CODE_GROUP_NAME"] == cg])
				slCg = slCg.append(sslCg.loc[sslCg["CODE_GROUP_NAME"] == cg])
				#print(sslJvs.loc[sslJvs["BUCKET"].str.contains(cg)])
				slJvs = slJvs.append(sslJvs.loc[sslJvs["BUCKET"].str.contains(cg)])
				for i,row in sslJvs.loc[sslJvs["BUCKET"].str.contains(cg)].iterrows():
					bt = row['BUCKET']
					os.system("cp -r " + oldSsl + "/" + bt + " " + newSl)
				
		#print("this flipping happens yooo")
		#print(slCgr)
		#print(slCg)
		#print(slJvs)
		slCgm.to_csv(cgmFile,sep="\t",index=False)
		slCgr.to_csv(cgrFile,sep="\t",index=False)
		slCg.to_csv(cgFile,sep="\t",index=False)
		slJvs.to_csv(jvsFile,sep="\t",index=False)
	for fl in os.listdir(slRt):
		if(os.path.isdir(slRt + "/" + fl)):
			if fl in sslSkip:
				os.system("cp -r " + slRt + "/" + fl + " " + outDir + "/" + fl + "_ignore")
				print("Skipping pxdx_report for injected SSL: " + fl)
				continue
			elif fl in mpDict:
				pass
			else:
				os.system("cp -r " + slRt + "/" + fl + " " + outDir)
			print("Running pxdx_report on " + fl + "...",end="")
			os.chdir(outDir + "/" + fl)
			os.system("pxdx_report --targets all &> config/stderroutMak")
			os.chdir("../../")
			print("done")
	#print(sslSkip)

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
