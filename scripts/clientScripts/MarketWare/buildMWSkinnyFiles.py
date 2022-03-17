#!/opt/local/marketview/conda/1/envs/master/bin/python

from dateutil.parser import parse as dt_parse
import logging
import argparse
import os, sys
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
import random
from multiprocessing import Process as prc
from mvUtil import miscfunctions as mf

logger = logging.getLogger(__name__)

piidList = set()
poidList = set()


def main():
    # tqdmLoop()
    parser = argparse.ArgumentParser(
        description="Consolidate PxDx output into skinny files."
    )
    parser.add_argument("-mDir")
    parser.add_argument("-netFile")

    args = parser.parse_args()
    # print(args)
    # print (args.mDir)
    if args.mDir is None or args.netFile is None:
        print("missing parameters")
        exit(args)
    mDir = re.sub("/$", "", args.mDir) + "/PxDx"
    iMDir = re.sub("/$", "", args.mDir) + "/INA"
    #print(mDir,iMDir)
    workDir = "work"
    outDir = os.path.abspath("mwSkinnyFiles")
    vintage = None
    if not os.path.exists("taxMap.txt"):
        exit("taxMap.txt file not found")
    for d in (workDir, outDir):
        if not os.path.exists(d):
            os.mkdir(d)
    iofh = open(outDir + "/Individual_Measures.txt","w")
    oofh = open(outDir + "/Organization_Measures.txt","w")
    aofh = open(outDir + "/Affiliation_Measures.txt","w")
    irofh = open(outDir + "/Individual_Rollup.txt","w")
    orofh = open(outDir + "/Organization_Rollup.txt","w")
    arofh = open(outDir + "/Affiliation_Rollup.txt","w")
    ipofh = open(outDir + "/Individual_Profiles.txt","w")
    opofh = open(outDir + "/Organization_Profiles.txt","w")
    nofh = open(outDir + "/Networks_Combined.txt","w")
    eofh = open(outDir + "/errorLog.txt","w")
    iofh.write(
        "\t".join(
            qw(
                "SUBSERVICE_LINE SETTING PIID PRACTITIONER_NATL_RANK AGE_BAND PRACTITIONER_TOTAL_PROCEDURES"
            )
        )
        + "\n"
    )
    oofh.write(
        "\t".join(
            qw(
                "SUBSERVICE_LINE SETTING POID FAC_NATL_RANK AGE_BAND FAC_TOTAL_PROCEDURES"
            )
        )
        + "\n"
    )
    aofh.write(
        "\t".join(
            qw(
                "SUBSERVICE_LINE SETTING AGE_BAND PIID POID PRACTITIONER_FAC_RANK PRACTITIONER_FAC_TOTAL_PROCEDURES HYBRID_WORKLOAD DATA_THROUGH"
            )
        )
        + "\n"
    )
    irofh.write(
        "\t".join(
            qw(
                "SUBSERVICE_LINE PIID PRACTITIONER_NATL_RANK PRACTITIONER_TOTAL_PROCEDURES"
            )
        )
        + "\n"
    )
    orofh.write(
        "\t".join(qw("SUBSERVICE_LINE POID FAC_NATL_RANK FAC_TOTAL_PROCEDURES")) + "\n"
    )
    arofh.write(
        "\t".join(
            qw(
                "SUBSERVICE_LINE PIID POID PRACTITIONER_FAC_RANK PRACTITIONER_FAC_TOTAL_PROCEDURES HYBRID_WORKLOAD"
            )
        )
        + "\n"
    )
    ipofh.write(
        "\t".join(
            qw(
                "PIID FIRST MIDDLE LAST SUFFIX CRED PRACTITIONER_TYPE SPEC1 SPEC2 MKT_SPEC1 MKT_SPEC2 TAXONOMY_CODE NPI ADDRESS1 ADDRESS2 CITY STATE ZIP ZIP4 PHONE1 FAX1 BIRTH_YEAR GENDER MED_SCHOOL GRADUATION_YEAR PATIENT_COUNT"
            )
        )
        + "\n"
    )
    opofh.write(
        "\t".join(
            qw(
                "POID ORGTYPE ORGNAME ADDRESS1 ADDRESS2 CITY STATE ZIP ZIP4 PHONE1 PHONE2 FAX1 NPI"
            )
        )
        + "\n"
    )
    nofh.write(
        "\t".join(
            qw(
                "SERVICELINE PIID1 GRP1_VOLUME_NATL_RANK NATL_NUM_CONN_GRP2_ENTITIES PIID2 GRP2_VOLUME_NATL_RANK NATL_NUM_CONN_GRP1_ENTITIES NATL_SOR_VALUE PCT1 PCT2 SharedPatientCount"
            )
        )
        + "\n"
    )
    nofh.close()
    
    #parseMDir(mDir,0)
    #parseMDir(iMDir,0)
    serviceLines = os.listdir(mDir)
    iServiceLines = os.listdir(iMDir)
    root = os.path.abspath(".")
    filtProcs = []
    semaphoreSize = 5
    exceptionSLs = ["Place_Exception","ServiceLines_Here"]
    checkBucket = "Anesthesia"
    # parse INA Files
    # first verify all filters have been built, and it not, throw them into a semaphore to run them concurrently
    print("Building Filter directories for all INAs which do not already have one...",end='')
    for sl in iServiceLines:
        # skip directory if it does not look like an INA dir
        if not os.path.exists(iMDir + "/" + sl + "/config"):
            continue
        elif sl in exceptionSLs:
            continue
        # elif sl != checkBucket:
        #     continue
        config = mf.createSettingDict("/".join([iMDir, sl, "config/settings.cfg"]))
        jobId = config["JOB_ID"][0]
        ncsFile = "/".join([iMDir,sl,"config","networkConfigSettings.tab"])
        ncs = pd.read_csv(ncsFile,sep="\t")
        # print(ncs)
        
        for i,row in ncs.iterrows():
            netName = row["NETWORK_NAME"]
            relTypes = row["RELATION_TYPES"].split(',')
            for relType in relTypes:
                inaComb = os.path.abspath("/".join([iMDir,sl,relType + "_" + netName,"Comb"]))
                filtDir = inaComb + "/Filter"
                if not os.path.exists(filtDir):
                    os.mkdir(filtDir)
                filtFile = "filter_inputs_NEW.txt"
                os.chdir(filtDir)
                # filter file doesn't exist. create it and build a filter set
                if not os.path.exists(filtFile):
                    p = prc(target=buildFilter,args=(filtFile,inaComb,jobId,netName,relType,))
                    filtProcs.append(p)
                    p.start()
                    if len(filtProcs) >= semaphoreSize:
                        for t in filtProcs:
                            t.join()
                        filtProcs.clear()
                os.chdir(root)
    # wait for any straggler threads
    for t in filtProcs:
        t.join()
    print("\ndone")
    
    #walk path again and grab results
    for sl in iServiceLines:
        # skip directory if it does not look like an INA dir
        if not os.path.exists(iMDir + "/" + sl + "/config"):
            continue
        elif sl in exceptionSLs:
            continue
        # elif sl != checkBucket:
        #     continue
        print("Grabbing Network Data For " + sl + "...",end='',flush=True)
        config = mf.createSettingDict("/".join([iMDir, sl, "config/settings.cfg"]))
        jobId = config["JOB_ID"][0]
        ncsFile = "/".join([iMDir,sl,"config","networkConfigSettings.tab"])
        ncs = pd.read_csv(ncsFile,sep="\t")
        for i,row in ncs.iterrows():
            netName = row["NETWORK_NAME"]
            relTypes = row["RELATION_TYPES"].split(',')
            for relType in relTypes:
                inaComb = os.path.abspath("/".join([iMDir,sl,relType + "_" + netName,"Comb"]))
                filtDir = inaComb + "/Filter"
                netFile = "network_full.txt"
                os.chdir(filtDir)
                if not os.path.exists(netFile):
                    print(netFile + " not found! Skipping")
                else:
                    netCols = qw("HMS_PIID1 GRP1_VOLUME_NATL_RANK NATL_NUM_CONN_GRP2_ENTITIES HMS_PIID2 GRP2_VOLUME_NATL_RANK NATL_NUM_CONN_GRP1_ENTITIES NATL_SOR_VALUE PCT1 PCT2 SharedPatientCount")
                    ndf = pd.read_csv(netFile,sep="\t",dtype=str,usecols=netCols)
                    ndf = ndf.rename(columns={"HMS_PIID1":"PIID1","HMS_PIID2":"PIID2"})
                    ndf.insert(0,"SERVICELINE",sl)
                    ndf.to_csv(outDir + "/Networks_Combined.txt",sep="\t",mode="a",index=False,header=False)
                    print("done")
                os.chdir(root)
    
    # parse PxDx Files
    for sl in serviceLines:
        # skip directory if it does not look like a PxDx dir
        if not os.path.exists(mDir + "/" + sl + "/config"):
            continue
        # 		elif(sl != "Anesthesia"):
        # 			continue
        else:
            print("Parsing " + sl + "...",end='',flush=True)
            config = mf.createSettingDict("/".join([mDir, sl, "config/settings.cfg"]))
            vintage = config["VINTAGE"][0]
            jvsFile = "/".join([mDir, sl, "config", "jobVendorSettings.tab"])
            #print("\t" + jvsFile)
            jvs = pd.read_csv(jvsFile, sep="\t")
            #print(jvs.head(10))
            # get list of measure buckets and rollup buckets and push them to sets
            measList = []
            rollList = []
            for i,row in jvs.iterrows():
                bucket = row["BUCKET"]
                #Check if a measure bucket
                if re.search("_(ip|op|office|asc)_(\d+)(_\d+)*$",bucket):
                    measList.append(bucket)
                #Check if a rollup bucket
                if not re.search("\d+$",bucket):
                    rollList.append(bucket)
            #print(yaml.dump(measList))
            #print(yaml.dump(rollList))
            #print(len(measList))
            #print(len(rollList))
            #exit()
            # process measure buckets into single output file
            for x in measList:
                ssl = getDataFromName(x, "subServ")
                setting = getDataFromName(x, "setting")
                ageBand = getDataFromName(x, "ageBand")
                # there are buckets with all settings/age bracket used for performance. they should be ignored
                #print("x: " + x)
                #print("ssl: " + ssl)
                #print("setting: " + setting)
                #print("ageBand: " + ageBand)
                parseIndivMeasure(mDir, sl, ssl, x, setting, ageBand, iofh, eofh)
                parseOrgsMeasure(mDir, sl, ssl, x, setting, ageBand, oofh, eofh)
                parsePxDxMeasure(mDir, sl, ssl, x, setting, ageBand, aofh, eofh)
            # process rollup buckets into single output file
            for x in rollList:
                ssl = x
                parseIndivMeasure(mDir, sl, ssl, x, "", "", irofh, eofh, rollup="Y")
                parseOrgsMeasure(mDir, sl, ssl, x, "", "", orofh, eofh, rollup="Y")
                parsePxDxMeasure(mDir, sl, ssl, x, "", "", arofh, eofh, rollup="Y")
            # print(jvs.BUCKET.tolist())
        print("done")
    for handle in (iofh, oofh, aofh, irofh, orofh, eofh):
        handle.close()

    # Building out Profile Tables
    # Get piid and poid values from network file
    netOutFile = outDir + "/Network.txt"
    netFields = qw(
        "HMS_PIID1 GRP1_VOLUME_NATL_RANK NATL_NUM_CONN_GRP2_ENTITIES HMS_PIID2 GRP2_VOLUME_NATL_RANK NATL_NUM_CONN_GRP1_ENTITIES NATL_SOR_VALUE PCT1 PCT2 SharedPatientCount"
    )
    fieldMap = {"HMS_PIID1": "PIID1", "HMS_PIID2": "PIID2"}
    mf.subsetTab(
        tabFile=args.netFile, fields=netFields, outFile=netOutFile, fieldMap=fieldMap
    )
    netDF = pd.read_csv(netOutFile, sep="\t", usecols=["PIID1", "PIID2"])
    for field in qw("PIID1 PIID2"):
        for piid in netDF[field].unique():
            piidList.add(piid)
    del netDF
    piidFile = workDir + "/piidList.tab"
    poidFile = workDir + "/poidList.tab"
    ilofh = open(piidFile, "w")
    olofh = open(poidFile, "w")
    ilofh.write("HMS_PIID\n")
    olofh.write("HMS_POID\n")
    for piid in sorted(piidList):
        ilofh.write(piid + "\n")
    for poid in sorted(poidList):
        olofh.write(poid + "\n")
    ilofh.close()
    olofh.close()
    # print(vintage)
    allCodesDir = getAllCodesDir(vintage)
    icifh = open(allCodesDir + "/milestones/individuals.tab", "r")
    icHeader = icifh.readline().rstrip("\n")
    icHeaderDict = mf.getHeaders(icHeader)
    icMap = {}
    for line in icifh:
        line = line.rstrip("\n")
        entry = line.split("\t")
        piid = entry[icHeaderDict["HMS_PIID"]]
        count = entry[icHeaderDict["ALL_CODES_PRACTITIONER_TOTAL_PATIENTS"]]
        icMap[piid] = count
    icifh.close()
    # print(icMap)
    tmifh = open("taxMap.txt", "r")
    tmHeader = tmifh.readline().rstrip("\n")
    tmHeaderDict = mf.getHeaders(tmHeader)
    tMap = {}
    for line in tmifh:
        line = line.rstrip("\n")
        entry = line.split("\t")
        taxCode = entry[tmHeaderDict["Taxonomy Code"]]
        mktSpec1 = entry[tmHeaderDict["MW_Specialty"]]
        mktSpec2 = entry[tmHeaderDict["MW_SubSpecialty"]]
        tMap[taxCode] = {}
        tMap[taxCode]["MKT_SPEC1"] = mktSpec1
        tMap[taxCode]["MKT_SPEC2"] = mktSpec2
    tmifh.close()
    # print(yaml.dump(tMap))
    # exit()
    mf.getProfileData(
        listFile=piidFile, vintage=vintage, toFile=workDir + "/piidProfs.tab"
    )
    ppifh = open(workDir + "/piidProfs.tab", "r")
    ppHeader = ppifh.readline()
    ppHeader = ppHeader.rstrip("\n")
    ppHeaderDict = mf.getHeaders(ppHeader)
    # 	print(ppHeaderDict)
    for line in ppifh:
        line = line.rstrip("\n")
        # 		print(line)
        entry = line.split("\t")
        piid = str(entry[ppHeaderDict["HMS_PIID"]])
        first = str(entry[ppHeaderDict["FIRST"]])
        middle = str(entry[ppHeaderDict["MIDDLE"]])
        last = str(entry[ppHeaderDict["LAST"]])
        suffix = str(entry[ppHeaderDict["SUFFIX"]])
        cred = str(entry[ppHeaderDict["CRED"]])
        practType = str(entry[ppHeaderDict["PRACTITIONER_TYPE"]])
        spec1 = str(entry[ppHeaderDict["HMS_SPEC1"]])
        spec2 = str(entry[ppHeaderDict["HMS_SPEC2"]])
        taxCode = str(entry[ppHeaderDict["NPI_TAXONOMY"]])
        mktSpec1 = str(tMap[taxCode]["MKT_SPEC1"]) if taxCode in tMap else ""
        mktSpec2 = str(tMap[taxCode]["MKT_SPEC2"]) if taxCode in tMap else ""
        npi = str(entry[ppHeaderDict["NPI"]])
        addr1 = str(entry[ppHeaderDict["ADDRESS1"]])
        addr2 = str(entry[ppHeaderDict["ADDRESS2"]])
        city = str(entry[ppHeaderDict["CITY"]])
        state = str(entry[ppHeaderDict["STATE"]])
        zipCode = str(entry[ppHeaderDict["ZIP"]])
        zip4 = str(entry[ppHeaderDict["ZIP4"]])
        phone = str(entry[ppHeaderDict["PHONE1"]])
        fax = str(entry[ppHeaderDict["FAX1"]])
        birthYear = str(entry[ppHeaderDict["YEAR_BORN"]])
        gender = str(entry[ppHeaderDict["GENDER"]])
        schoolName = str(entry[ppHeaderDict["SCHOOL_NAME"]])
        gradYear = str(entry[ppHeaderDict["GRAD_YEAR"]])
        patCount = str(icMap[piid]) if piid in icMap else ""
        ipofh.write(
            "\t".join(
                [
                    piid,
                    first,
                    middle,
                    last,
                    suffix,
                    cred,
                    practType,
                    spec1,
                    spec2,
                    mktSpec1,
                    mktSpec2,
                    taxCode,
                    npi,
                    addr1,
                    addr2,
                    city,
                    state,
                    zipCode,
                    zip4,
                    phone,
                    fax,
                    birthYear,
                    gender,
                    schoolName,
                    gradYear,
                    patCount,
                ]
            )
            + "\n"
        )
    # print(indivCountMap.head())
    # print(piidProfsRaw.head())
    poidProfs = mf.getProfileData(listFile=poidFile, vintage=vintage)
    # print(poidProfs)
    poidProfs[
        [
            "HMS_POID",
            "ORGTYPE",
            "ORGNAME",
            "ADDRESS1",
            "ADDRESS2",
            "CITY",
            "STATE",
            "ZIP",
            "ZIP4",
            "PHONE1",
            "PHONE2",
            "FAX1",
            "NPI",
        ]
    ].to_csv(opofh, mode="a", header=False, index=False, sep="\t")
    ppifh.close()
    ipofh.close()
    opofh.close()

    # Build payermix
    mf.getRxPayermix(piidList, vintage, outFile=outDir + "/Payermix.txt", exclude=[0])

    os.system("chmod 777 -R " + outDir)


def parseMDir(dirName, depth):
    # create a list of file and sub directories
    # names in the given directory
    listOfFiles = os.listdir(dirName)
    # print(listOfFiles,depth)
    for x in listOfFiles:
        fullPath = os.path.join(dirName, x)
        if os.path.isdir(fullPath):
            print(" " * depth + x + "/")
            parseMDir(fullPath, depth + 1)
        else:
            print(" " * depth + x)


def getDataFromName(bucketName, dataType):
    # split on _ get last string which isn't a number
    bucketArr = bucketName.split("_")
    retArr = []
    subSetFound = 0
    for i in reversed(bucketArr):
        if dataType == "setting":
            if not i.isnumeric():
                retArr.append(i)
                break
        elif dataType == "ageBand":
            if i.isnumeric():
                retArr.insert(0, i)
        elif dataType == "subServ":
            if not i.isnumeric():
                if subSetFound == 0:
                    subSetFound = 1
                else:
                    retArr.insert(0, i)
    if dataType == "ageBand" and len(retArr) == 1:
        retArr[0] += "+"
    return "_".join(retArr)


def parseIndivMeasure(mDir, sl, ssl, x, setting, ageBand, iofh, eofh, rollup=""):
    indivFile = "/".join([mDir, sl, x, "milestones", "individuals.tab"])
    if os.path.exists(indivFile):
        indDF = pd.read_csv(indivFile, sep="\t")
        #print(indDF.SUBSERVICE_LINE.unique())
        #exit()
        if indDF.empty:
            eofh.write("indivFile: " + indivFile + " has no data\n")
        else:
            for piid in indDF.HMS_PIID.unique():
                piidList.add(piid)
            if rollup != "":
                indDF["SUBSERVICE_LINE"] = ssl
                indDF[
                    [
                        "SUBSERVICE_LINE",
                        "HMS_PIID",
                        x + "_PRACTITIONER_NATL_RANK",
                        x + "_PRACTITIONER_TOTAL_PROCS",
                    ]
                ].to_csv(iofh, mode="a", header=False, index=False, sep="\t")
            else:
                indDF["SUBSERVICE_LINE"] = ssl
                indDF["SETTING"] = setting
                indDF["AGE_BAND"] = ageBand
                indDF[
                    [
                        "SUBSERVICE_LINE",
                        "SETTING",
                        "HMS_PIID",
                        x + "_PRACTITIONER_NATL_RANK",
                        "AGE_BAND",
                        x + "_PRACTITIONER_TOTAL_PROCS",
                    ]
                ].to_csv(iofh, mode="a", header=False, index=False, sep="\t")


def parseOrgsMeasure(mDir, sl, ssl, x, setting, ageBand, oofh, eofh, rollup=""):
    orgsFile = "/".join([mDir, sl, x, "milestones", "organizations.tab"])
    if os.path.exists(orgsFile):
        orgDF = pd.read_csv(orgsFile, sep="\t")
        if orgDF.empty:
            eofh.write("orgFile: " + orgsFile + " has no data\n")
        else:
            for poid in orgDF.HMS_POID.unique():
                poidList.add(poid)
            if rollup != "":
                orgDF["SUBSERVICE_LINE"] = ssl
                orgDF[
                    [
                        "SUBSERVICE_LINE",
                        "HMS_POID",
                        x + "_FAC_NATL_RANK",
                        x + "_FAC_TOTAL_PROCS",
                    ]
                ].to_csv(oofh, mode="a", header=False, index=False, sep="\t")
            else:
                orgDF["SUBSERVICE_LINE"] = ssl
                orgDF["SETTING"] = setting
                orgDF["AGE_BAND"] = ageBand
                orgDF[
                    [
                        "SUBSERVICE_LINE",
                        "SETTING",
                        "HMS_POID",
                        x + "_FAC_NATL_RANK",
                        "AGE_BAND",
                        x + "_FAC_TOTAL_PROCS",
                    ]
                ].to_csv(oofh, mode="a", header=False, index=False, sep="\t")


def parsePxDxMeasure(mDir, sl, ssl, x, setting, ageBand, aofh, eofh, rollup=""):
    pxdxFile = "/".join([mDir, sl, x, "milestones", "pxdx.tab"])
    if os.path.exists(pxdxFile):
        pxdxDF = pd.read_csv(pxdxFile, sep="\t", low_memory=False)
        if pxdxDF.empty:
            eofh.write("pxdxFile: " + pxdxFile + " has no data\n")
        elif rollup != "":
            pxdxDF["SUBSERVICE_LINE"] = ssl
            pxdxDF[
                [
                    "SUBSERVICE_LINE",
                    "HMS_PIID",
                    "HMS_POID",
                    x + "_PRACTITIONER_FAC_RANK",
                    x + "_PRACTITIONER_FAC_TOTAL_PROCS",
                    x + "_EXACT_WORKLOAD",
                ]
            ].to_csv(aofh, mode="a", header=False, index=False, sep="\t")
        else:
            config = mf.createSettingDict("/".join([mDir, sl, "config/settings.cfg"]))
            jobId = config["JOB_ID"][0]
            # print(yaml.dump(config))
            # print(jobId)
            jvSql = (
                "select max(last_vend_date) as Data_Through from job_vendors t where t.job_id = '"
                + jobId
                + "'"
            )
            maxDate = mf.getOracleSql(
                oraUser="claims_aggr",
                oraPass="Hydr0gen2014",
                oraInst="PLDWH2DBR",
                sql=jvSql,
            )
            dataThrough = mf.normalizeDate(maxDate.loc[0]["DATA_THROUGH"])
            pxdxDF["SUBSERVICE_LINE"] = ssl
            pxdxDF["SETTING"] = setting
            pxdxDF["AGE_BAND"] = ageBand
            pxdxDF["DATA_THROUGH"] = dataThrough
            pxdxDF[
                [
                    "SUBSERVICE_LINE",
                    "SETTING",
                    "AGE_BAND",
                    "HMS_PIID",
                    "HMS_POID",
                    x + "_PRACTITIONER_FAC_RANK",
                    x + "_PRACTITIONER_FAC_TOTAL_PROCS",
                    x + "_EXACT_WORKLOAD",
                    "DATA_THROUGH",
                ]
            ].to_csv(aofh, mode="a", header=False, index=False, sep="\t")


def getAllCodesDir(vintage):
    monthMap = {
        "01": "Jan",
        "02": "Feb",
        "03": "Mar",
        "04": "Apr",
        "05": "May",
        "06": "Jun",
        "07": "Jul",
        "08": "Aug",
        "09": "Sep",
        "10": "Oct",
        "11": "Nov",
        "12": "Dec",
    }
    yyDate = mf.normalizeDate(date=vintage, yyyymmdd="Y")
    month = monthMap[yyDate[4:6]]
    year = yyDate[0:4]
    pathRoot = (
        "/vol/cs/clientprojects/PxDxStandardizationTesting/MonthlyAllCodes/"
        + month
        + year
        + "/PT_HOA_E"
    )
    return pathRoot

def buildFilter(filtFile,inaComb,jobId,netName,relType):
    print("\n\tBuilding Filter for " + netName + "...",end='')
    fofh = open(filtFile, "w")
    generateFINFile(fofh,inaComb,jobId,netName,relType)
    fofh.close()
    os.system("oraTerrFilter.pl -input " + filtFile + " &> stderrout")

def generateFINFile(fofh,inaComb,jobId,netName,relType):
    denomFile = os.path.abspath(inaComb + "/denom_fordelivery.txt")
    fofh.write("#input parameters for filtering code\n")
    fofh.write("\n")
    fofh.write("#Strength of Relationship Mapping\n")
    fofh.write("#Every strength value in linkssummary.txt (first column) needs to have a label\n")
    fofh.write("#StrengthMap\tStrength\tLabel\n")
    fofh.write("StrengthMap\t0\t1\n")
    fofh.write("StrengthMap\t1\t2\n")
    fofh.write("StrengthMap\t2\t3\n")
    fofh.write("StrengthMap\t3\t4\n")
    fofh.write("StrengthMap\t4\t5\n")
    fofh.write("StrengthMap\t5\t6\n")
    fofh.write("StrengthMap\t6\t7\n")
    fofh.write("StrengthMap\t7\t8\n")
    fofh.write("StrengthMap\t8\t9\n")
    fofh.write("StrengthMap\t9\t10\n")
    fofh.write("\n")
    fofh.write("#Filtering/decile replacement file\n")
    fofh.write("#PxFilter info will be ignored for Dx-only network\n")
    fofh.write("#For Dx->Px network can specify both files or one can be blank\n")
    fofh.write("#if dxfilter is not needed - but dxuniverse is needed below - specify the dxuniverse column names here\n")
    fofh.write("#Filetype\tFilename - full path\tDecile Col Name - can be blank if no need to replace decile\tCount Col Name - can be blank\n")
    fofh.write("Grp1Filter\t" + denomFile + "\n")
    fofh.write("Grp2Filter\t" + denomFile + "\n")
    fofh.write("\n")
    fofh.write("#Universe of PIIDs file - if we want to restrict PIIDs in the network to be from some universe\n")
    fofh.write("#leave filename blank if universe restriction not required\n")
    fofh.write("#must specify a Dx and a Px universe, with counts if merging to PxDx\n")
    fofh.write("#assumes the counts and decile column names are same as in the filter files\n")
    fofh.write("#no need to respecify\n")
    fofh.write("#Filetype\tFilename - full path\n")
    fofh.write("Grp1Univ\t" + denomFile + "\n")
    fofh.write("Grp2Univ\t" + denomFile + "\n")
    fofh.write("\n")
    fofh.write("#PxDx affiliations tab files - if we want to filter them to the list of piids in network.txt\n")
    fofh.write("PxDxAffils_Grp2\t\n")
    fofh.write("\n")
    fofh.write("#second tab file - if we want to filter it to the list of second ids in the filtered pxdx\n")
    fofh.write("PxDxSecondFile_Grp2\t\n")
    fofh.write("\n")
    fofh.write("#PxDx affiliations tab files - if we want to filter them to the list of piids in network.txt\n")
    fofh.write("PxDxAffils_Grp1\t\n")
    fofh.write("\n")
    fofh.write("#second tab file - if we want to filter it to the list of second ids in the filtered pxdx\n")
    fofh.write("PxDxSecondFile_Grp1\t\n")
    fofh.write("\n")
    fofh.write("\n")
    fofh.write("Relational\tHYBRID\n")
    fofh.write("AddCounts\tY\n")
    fofh.write("\n")
    fofh.write("InaJobId\t" + jobId + "\n")
    fofh.write("NetworkName\t" + netName + "\n")
    fofh.write("RelationType\t" + relType + "\n")

def printNums(x):
    for y in range(10):
        time.sleep(10 * random.random())
        print(str(x) + ":" + str(y))

def tqdmLoop():
    for i in tqdm(range(0, 100), desc="tqdm sample"):
        sleep(0.5)


def qw(stringList):
    return tuple(stringList.split())


if __name__ == "__main__":
    startTime = time.time()
    main()
    endTime = time.time()
    hours, rem = divmod(endTime - startTime, 3600)
    minutes, seconds = divmod(rem, 60)
    print(
        "Program:\n\t"
        + __file__
        + "\nRun Time: {:0>2}:{:0>2}:{:05.2f}".format(int(hours), int(minutes), seconds)
    )
