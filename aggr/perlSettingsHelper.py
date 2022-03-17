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

#code to take a simplified cfg file and write it to pretty formatted style based on yaml files for
#pxdx, ina, and prim cfgs. Workaround since Perl really doesn't like my yaml templates

def main():
	#tqdmLoop()
	parser = argparse.ArgumentParser(description="Read in a config file.")
	parser.add_argument("-config", "--config",required=True)
	parser.add_argument("-outFile","--outFile",default="settings.cfg")
	
	args = parser.parse_args()
	#print(args)
	#print(args.config)
	#print(args.outFile)
	setVars = mf.createSettingDict(args.config)
	#print(setVars)
	mf.writeSettingFile(setVars,args.outFile)

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
