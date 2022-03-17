#!/opt/local/marketview/conda/envs/envs/dev/bin/python

from dateutil.parser import parse as dtParse
import logging
import argparse
import os,sys,getpass
import warnings
import json
import yaml
import pandas as pd
import numpy as np
import cx_Oracle as cxo
from contextlib import closing
import itertools, collections
from tqdm import tqdm
import time
from datetime import datetime
import re
import aggr
from mvUtil import miscfunctions as mf

logger = logging.getLogger(__name__)
configPath = None
oraInst = None
oraUser = None
oraPass = None
setVars = None
logDir = None
memoryHash = {}
offset = None


def main():
    # tqdmLoop()
    parser = argparse.ArgumentParser(description="""Script to build a Pri+ job. See
    /vol/cs/clientprojects/mv_utilities/aggr/pri/priPlus/config/README for further details""")
    parser.add_argument("-config", "--config", required=True)
    for arg in ["loadOnly", "aggrOnly", "resume", "msOnly"]:
        parser.add_argument("-" + arg, "--" + arg, action="store_true")

    args = parser.parse_args()
    # print(args)
    # print(args.config)

    global setVars, logDir, memoryHash, configPath, oraInst, oraUser, oraPass
    configPath = args.config
    setVars = mf.createSettingDict(args.config)
    cfgPath = os.path.abspath(configPath)
    projDir = os.path.dirname(cfgPath)
    superProjDir = os.path.dirname(projDir)
    try:
        os.makedirs(projDir + "/logFiles")
    except:
        pass
    logDir = projDir + "/logFiles"
    # print(yaml.dump(setVars))
    oraInst = setVars["INSTANCE"][0]
    oraUser = setVars["USERNAME"][0]
    oraPass = setVars["PASSWORD"][0] if setVars["PASSWORD"] else "Hydr0gen2014"

    if args.loadOnly:
        jobId = loadPriPlus(setVars)
        print(
            "Job_Id: "
            + jobId
            + " loadOnly flag given. Job must be manually pushed into queue"
        )
    elif args.aggrOnly:
        buildPriPlus(setVars)
        jobId = setVars["JOB_ID"][0]
        trackJob(jobId)
        print(
            "Job_Id: "
            + jobId
            + " aggrOnly flag given. priPlusReport.py must be run for final deliverable"
        )
    elif args.resume:
        jobId = -1
        try:
            jobId = setVars["JOB_ID"][0]
        except:
            exit("No JOB_ID supplied. Cannot pull Pri+ data")
        trackJob(jobId,True)
        os.system("priPlusReport.py -config " + args.config)
    elif args.msOnly:
        jobId = -1
        try:
            jobId = setVars["JOB_ID"][0]
        except:
            exit("No JOB_ID supplied. Cannot pull Pri+ data")
        print(
            "Job_Id: "
            + jobId
            + " msOnly flag given. Assuming data pull is finished and running priPlusReport.py",
            flush=True
        )
        os.system("priPlusReport.py -config " + args.config)
    else:
        jobId = loadPriPlus(setVars)
        print(
            "Job_Id: "
            + jobId
            + " settings have been successfully loaded. Pushing job into queue"
        )
        queueId = buildPriPlus(setVars)
        print(
            "Job has been inserted into schedule. Job_Id: "
            + str(jobId)
            + ". Queue_Id: "
            + str(queueId)
        )
        print(
            'Please look at the file "buildPriStatusLog.txt" in logFiles to see the status of your Pri Job'
        )
        trackJob(jobId)
        print(
            "Job_Id: "
            + jobId
            + " data pull finished. Proceeding to run priPlusReport.py"
        )
        os.system("priPlusReport.py -config " + args.config)


def tqdmLoop():
    for i in tqdm(range(0, 100), desc="tqdm sample"):
        sleep(0.5)


def loadPriPlus(setVars):
    jobName = setVars["JOB_NAME"][0]
    vint = mf.normalizeDate(setVars["VINTAGE"][0])
    claimsDatabase = setVars["CLAIMS_DATABASE"][0]
    repType = setVars["REPORT_TYPE"][0]
    dosWin = setVars["DOS_WINDOW"][0] if setVars["DOS_WINDOW"] else ""
    procCodesFile = setVars["PROCEDURE_CODES_FILE"][0]
    adjustFile = setVars["ADJUSTMENTS_FILE"][0]
    # print('-'.join([oraInst,oraUser,oraPass,jobName,vint,repType,dosWin,procCodesFile,adjustFile]))

    global logDir
    lfh = open(logDir + "/setupPriPlusJobLog.txt", "a")

    procsSql = """select proc.procedure_id as memeber_id,
		proc.addnl_procedure_code as memeber_code,
		proc.code_scheme as memeber_scheme
		from claimswh.procedures proc where proc.code_scheme != 'UNKNOWN'"""

    diagsSql = """select diag.diagnosis_id as memeber_id,
		diag.addnl_diagnosis_code as memeber_code,
		diag.code_scheme as memeber_scheme
		from claimswh.diagnosis diag where diag.code_scheme != 'UNKNOWN'"""

    drgsSql = """select drgs.drg_id as memeber_id,
		drgs.drg_code as memeber_code,
		drgs.code_scheme as memeber_scheme
		from claimswh.drgs drgs where drgs.code_scheme = 'MS'"""

    procModsSql = """select procMod.proc_modifier_id as memeber_id,
		procMod.modifier_code as memeber_code,
		procMod.code_scheme as memeber_scheme
		from claimswh.proc_modifiers procMod where procMod.code_scheme != 'UNKNOWN'"""

    memoryHash["PX_TABLE"] = mf.getOracleSql(oraInst, oraUser, oraPass, procsSql)
    memoryHash["DX_TABLE"] = mf.getOracleSql(oraInst, oraUser, oraPass, diagsSql)
    memoryHash["DRG_TABLE"] = mf.getOracleSql(oraInst, oraUser, oraPass, drgsSql)
    memoryHash["MOD_TABLE"] = mf.getOracleSql(oraInst, oraUser, oraPass, procModsSql)

    # for x in ["PX","DX","DRG","MOD"]:
    # 	print(memoryHash[x + "_TABLE"].head(3))

    memoryHash["CODES_FILE"] = pd.read_csv(procCodesFile, sep="\t")
    memoryHash["CODES_FILE"]["TYPE"] = memoryHash["CODES_FILE"]["TYPE"].str.upper()
    memoryHash["ADJ_FILE"] = pd.read_csv(adjustFile, sep="\t")

    # verify codes file and produce produce maps for code and adjustment groups in memoryHash
    verifySrcFiles()

    # insert job into pri_jobs
    priJobsSql = (
        """declare
			l_Job_Id NUMBER;
			begin
				INSERT INTO Pri_Jobs
					(Pri_Job_Id,
					Pri_Job_Name,
					Pri_Job_Status,
					Pri_Job_Type,
					Xwalk_Date)
				VALUES
					(pri_job_seq.Nextval,
					'"""
        + jobName
        + """',
					'PENDING',
					'ADJ',
					To_Date('"""
        + vint
        + """','mm/dd/yyyy'))
					RETURNING Pri_Job_Id INTO l_Job_Id;
					commit;
				dbms_output.Put_line(l_Job_Id);
			end;"""
    )
    jobId = mf.getOracleSql(oraInst, oraUser, oraPass, priJobsSql, outString="Y")[0]
    # print(jobId)
    setVars["JOB_ID"] = [jobId]
    yamlTemp = aggr.__path__._path[0] + "/pri/priPlus/priPlusSettings.yaml"
    mf.writeSettingFile(setVars, yamlPath=yamlTemp)

    global offset
    offset = int(jobId) * 10000

    insertCodeGroups(setVars)
    lfh.write("Job_Id: " + jobId + ". Inserted data into Pri_Code_Groups\n")
    insertCodeGroupMembers(setVars)
    lfh.write("Job_Id: " + jobId + ". Inserted data into Pri_Code_Group_Members\n")
    insertJobVendorSettings(setVars)
    lfh.write("Job_Id: " + jobId + ". Inserted data into Pri_Job_Vendor_Settings\n")
    insertAdjGroups(setVars)
    lfh.write("Job_Id: " + jobId + ". Inserted data into Pri_Adjust_Reason_Groups\n")
    insertAdjGroupMembers(setVars)
    lfh.write("Job_Id: " + jobId + ". Inserted data into Pri_Adjust_Reason_Members\n")
    lfh.write("\n")
    lfh.close()

    # insert pri_job_vendors
    prodWindow = "QUARTERLY"
    prodWindowSql = (
        "Begin pkg_aggr_util.Insert_Pri_Job_Vendors(p_Job_Id => "
        + jobId
        + ",p_Job_Frequency => '"
        + prodWindow
        + "'); end;"
    )
    mf.getOracleSql(oraInst, oraUser, oraPass, prodWindowSql)
    if claimsDatabase.lower() == "premium":
        addWSSql = (
            "Begin pkg_aggr_util.Insert_Pri_Job_Vendors_Waystar(p_Job_Id => "
            + jobId
            + ",p_Job_Frequency => '"
            + prodWindow
            + "'); end;"
        )
        mf.getOracleSql(oraInst, oraUser, oraPass, addWSSql)
    return jobId


def buildPriPlus(setVars):
    global memoryHash, oraInst, oraUser, oraPass, configPath
    # print(yaml.dump(setVars))
    oraInst = setVars["INSTANCE"][0]
    oraUser = setVars["USERNAME"][0]
    oraPass = setVars["PASSWORD"][0] if setVars["PASSWORD"] else "Hydr0gen2014"
    cfgPath = os.path.abspath(configPath)
    projDir = os.path.dirname(cfgPath)
    superProjDir = os.path.dirname(projDir)
    user = getpass.getuser()
    jobId = -1
    try:
        jobId = setVars["JOB_ID"][0]
    except:
        exit("No JOB_ID supplied. Cannot pull Pri+ data\n")
    jobName = setVars["JOB_NAME"][0]
    vint = mf.normalizeDate(setVars["VINTAGE"][0], yyyymmdd="Y")
    claimsDatabase = setVars["CLAIMS_DATABASE"][0]
    repType = setVars["REPORT_TYPE"][0]
    dosWin = setVars["DOS_WINDOW"][0] if setVars["DOS_WINDOW"] else ""
    procCodesFile = setVars["PROCEDURE_CODES_FILE"][0]
    adjustFile = setVars["ADJUSTMENTS_FILE"][0]
    # print('-'.join([oraInst,oraUser,oraPass,jobId,jobName,vint,repType,dosWin,procCodesFile,adjustFile]))

    # insert job into queue
    queue = "PRPLQ"
    pkg = "pkg_pri_plus"
    addJobSql = (
        """select
		Pkg_Manage_Job_Queue.Add_Job_To_Queue(
			p_Queue_Name => '"""
        + queue
        + """',p_What => 'Begin """
        + pkg
        + """.Generate_Aggr(
			p_Job_Id => """
        + jobId
        + """,
			p_Xwalk_Date => to_date(''"""
        + vint
        + """'',''yyyymmdd'')
			); end;',p_Job_Process_Id => """
        + jobId
        + """,
            p_Job_Path => '"""
        + superProjDir
        + """',
            p_Job_User_Name => '"""
        + user
        + """') as QUEUE_ID
			from dual"""
    )
    queueId = mf.getOracleSql(oraInst, oraUser, oraPass, addJobSql).iloc[0]["QUEUE_ID"]

    global logDir
    lfh = open(logDir + "/insertPriIntoQueueLog.txt", "a")
    lfh.write("Job_Process_Id: " + str(jobId) + "\n")
    lfh.write("Job_Queue_Id: " + str(queueId) + "\n\n")
    lfh.close()

    return queueId


def trackJob(jobId,resume=False):
    status = getJobStatus(jobId)
    queueId = getQueueId(jobId)
    # print("status is: " + status)
    startedRunning = False

    jobStartTime = datetime.now()

    iTime = datetime.now()
    global configPath, logDir

    while status not in ("STOPPED", "FAILED", "SUCCEEDED"):
        # Job Status is Pending
        if status not in ("RUNNING", "FINISHED"):
            cTime = datetime.now()
            sfh = open(logDir + "/buildPriStatusLog.txt", "w")
            sfh.write(
                "Job Id: "
                + str(jobId)
                + ". Job Queue Id: "
                + str(queueId)
                + ". Status: Pending. Time: "
                + "/".join(str(t) for t in (cTime.month, cTime.day, cTime.year))
                + " "
                + ":".join(str(t) for t in (cTime.hour, cTime.minute, cTime.second))
                + "\n"
            )
            sfh.close()
        # Job Status is Running/"Finished" and being copied to the aggregations table
        else:
            if not startedRunning:
                startedRunning = True
            getJobLogs(jobId, jobStartTime)
        time.sleep(60)
        status = getJobStatus(jobId)

    # sfh = open (logDir + "/buildPriStatusLog.txt","a")
    # sfh.write("Job complete. Status: " + status + "\n")
    # sfh.close()

    if status == "SUCCEEDED":
        print("Job_Id: " + jobId + " data pull complete\n")

    projDir = os.path.dirname(os.path.abspath(configPath))
    subject = 'Pri Plus Job: "' + setVars["JOB_NAME"][0] + '" complete'
    message = "\n".join(
        [
            "Your Pri Plus data pull is finished running.",
            "\t" + projDir,
            "\tJOB_ID: " + jobId,
            "\tVINTAGE: " + setVars["VINTAGE"][0],
            "\tSTATUS: " + status + "\n",
        ]
    )
    mf.sendEmail(subject, message)


def verifySrcFiles():
    cdf = memoryHash["CODES_FILE"][["CODE_GROUP", "TYPE"]]
    adf = memoryHash["ADJ_FILE"]
    memoryHash["CODE_GROUPS"] = {}
    # print(cdf)
    for i, row in cdf.iterrows():
        # print(row)
        cg = str(row["CODE_GROUP"])
        typ = str(row["TYPE"]).upper()
        if not cg in memoryHash["CODE_GROUPS"]:
            memoryHash["CODE_GROUPS"][cg] = {}
            memoryHash["CODE_GROUPS"][cg]["CODE_GROUP"] = cg
            memoryHash["CODE_GROUPS"][cg]["TYPE"] = typ
        elif typ != memoryHash["CODE_GROUPS"][cg]["TYPE"]:
            exit("Codes file error - Code Group: " + cg + " has more than one type!")
        # print('-'.join([cg,typ]))
    # print(yaml.dump(memoryHash["CODE_GROUPS"]))
    # code group/type 1 to 1 check passed. assign code group ids
    for i, cg in enumerate(cdf["CODE_GROUP"].unique()):
        memoryHash["CODE_GROUPS"][cg]["CODE_GROUP_ID"] = i + 1


def insertCodeGroups(setVars):
    jobId = setVars["JOB_ID"][0]
    cdf = memoryHash["CODES_FILE"]
    global oraInst, oraUser, oraPass
    for i, cg in enumerate(cdf["CODE_GROUP"].unique()):
        codeGroupId = str(memoryHash["CODE_GROUPS"][cg]["CODE_GROUP_ID"] + offset)
        codeGroupName = cg
        codeGroupType = memoryHash["CODE_GROUPS"][cg]["TYPE"]
        # print('-'.join([codeGroupId,codeGroupName,codeGroupType]))
        codeGroupSql = (
            """begin
			INSERT INTO Pri_Code_Groups
				(Pri_Job_Id,
				Code_Group_Id,
				Code_Group_Name,
				Code_Group_Type)
			VALUES
				('"""
            + jobId
            + """',
				'"""
            + codeGroupId
            + """',
				'"""
            + codeGroupName
            + """',
				'"""
            + codeGroupType
            + """');
				commit;
				end;"""
        )
        mf.getOracleSql(oraInst, oraUser, oraPass, codeGroupSql)
    # print(offset)
    # print(memoryHash["CODE_GROUPS"])


def insertCodeGroupMembers(setVars):
    jobId = setVars["JOB_ID"][0]
    cdf = memoryHash["CODES_FILE"]
    global oraInst, oraUser, oraPass
    memberRows = []
    for i, row in cdf.iterrows():
        codeGroupName = row["CODE_GROUP"]
        codeGroupType = row["TYPE"]
        code = row["CODE"]
        codeScheme = row["SCHEME"]
        codeGroupId = str(
            memoryHash["CODE_GROUPS"][codeGroupName]["CODE_GROUP_ID"] + offset
        )
        memberTable = memoryHash[codeGroupType.upper() + "_TABLE"]
        memberIds = memberTable.loc[memberTable["MEMEBER_CODE"] == str(code)]
        # print(memberTable.head(3))
        # print(memberIds)
        for j, memberRow in memberIds.iterrows():
            memId = memberRow["MEMEBER_ID"]
            memberRows.append((codeGroupId, codeGroupType, memId))
            # print(memId)
        # sql = "select * from sometable where somefield = :myField and otherfield = :anotherOne"
        # cur.execute(sql, myField=aValue, anotherOne=anotherValue)
        # print(i,row)
        # print([codeGroupName,codeGroupType,code,codeScheme,codeGroupId])
        # cgi,cgt,mem
    # print(memberRows)
    conn = cxo.connect(oraUser, oraPass, oraInst)
    cursor = conn.cursor()
    cursor.executemany(
        """begin insert INTO Pri_Code_Group_Members
		(Code_Group_Id,
		Code_Group_Type,
		Member_Id)
	values(:1,:2,:3);commit;end;""",
        memberRows,
    )


def insertJobVendorSettings(setVars):
    jobId = setVars["JOB_ID"][0]
    global oraInst, oraUser, oraPass
    vendorSettingsSql = "select * from Pri_Vendor_Settings"
    pvsDF = mf.getOracleSql(oraInst,oraUser,oraPass,vendorSettingsSql)
    #print(pvsDF)
    
    allSettings = {}
    settings = setVars["SETTINGS"][0].lower().split(',')
    for sett in settings:
        if sett == "ip":
            allSettings["inpatient"] = sett
        elif sett == "op":
            allSettings["outpatient"] = sett
        elif sett == "misc":
            allSettings["other"] = sett
            allSettings["none"] = sett
        else:
            allSettings[sett] = sett
    #print(allSettings)
    
    settingsToPush = {}
    for i,row in pvsDF.iterrows():
        aggrName = row["AGGR_NAME"]
        if aggrName.lower() in allSettings:
            vendorSettingId = row["PRI_VENDOR_SETTING_ID"]
            settingsToPush[vendorSettingId] = aggrName
    #print(settingsToPush)
    
    for vsi in settingsToPush:
        jvsSql = """begin
 					INSERT INTO Pri_Job_Vendor_Settings
 						(Pri_Job_Id,
 						Pri_Vendor_Setting_Id)
 					VALUES
 						('""" + jobId + """',
 						'""" + str(vsi) + """');
 					commit;
 				end;"""
        mf.getOracleSql(oraInst,oraUser,oraPass,jvsSql)

def insertAdjGroups(setVars):
    jobId = setVars["JOB_ID"][0]
    global oraInst, oraUser, oraPass
    adjGroupId = str(jobId)
    adjGroupName = "Adj_" + adjGroupId
    # print('-'.join([adjGroupId,adjGroupName]))
    adjGroupSql = (
        """begin
		INSERT INTO Pri_Adjust_Reason_Groups
			(Pri_Job_Id,
			Adjust_Reason_Group_Id,
			Adjust_Reason_Group_Name)
		VALUES
			('"""
        + jobId
        + """',
			'"""
        + adjGroupId
        + """',
			'"""
        + adjGroupName
        + """');
			commit;
			end;"""
    )
    mf.getOracleSql(oraInst, oraUser, oraPass, adjGroupSql)
    # print(memoryHash["ADJ_GROUPS"])


def insertAdjGroupMembers(setVars):
    global oraInst, oraUser, oraPass
    jobId = setVars["JOB_ID"][0]
    adf = memoryHash["ADJ_FILE"]
    #print(adf)
    #We need to map adjustment codes to their associated adjustment IDs in Oracle. get rows that matter
    requestedArcSet = set(adf["ADJ_CODE"].unique())
    #always pull deductible, copay, coinsurance
    for x in (1,2,3):
        requestedArcSet.add(x)
    requestedArcs = tuple(sorted(requestedArcSet))
    reqTup = "('" + "','".join(str(x) for x in requestedArcs) + "')"
    adjMapSql = "select * from claimswh.adjustment_reasons t where adjust_reason_code in " + reqTup
    adjMapDf = mf.getOracleSql(oraInst, oraUser, oraPass, adjMapSql)
    #print(adjMapDf)
    memberRows = []
    for arc in requestedArcs:
        #print(arc)
        adjGroupId = jobId
        adjCode = arc
        adjMem = str(adjMapDf.loc[adjMapDf["ADJUST_REASON_CODE"] == str(adjCode),"ADJUST_REASON_ID"].values[0])
        memberRows.append((adjGroupId, adjMem))
    #print(memberRows)
    #exit()
    conn = cxo.connect(oraUser, oraPass, oraInst)
    cursor = conn.cursor()
    cursor.executemany(
        """begin insert INTO Pri_Adjust_Reason_Members
		(Adjust_Reason_Group_Id,
		Member_Id)
	values(:1,:2);commit;end;""",
        memberRows,
    )


def getJobStatus(jobId):
    global oraInst, oraUser, oraPass
    jobStatusSql = (
        "select Job_Status from Aggr_Queue_Jobs aqj where aqj.Job_Process_Id = '"
        + jobId
        + "' and aqj.Job_Queue_Id = (select max(mx.Job_Queue_Id) from Aggr_Queue_Jobs mx where mx.Job_Process_Id = aqj.Job_Process_Id)"
    )
    jobStatus = mf.getOracleSql(oraInst, oraUser, oraPass, jobStatusSql).iloc[0][
        "JOB_STATUS"
    ]
    # print(jobStatus)
    if jobStatus == "":
        exit("Job Id: " + jobId + ". Status not found!\n")
    return jobStatus


def getQueueId(jobId):
    global oraInst, oraUser, oraPass
    queueIdSql = (
        "select Job_Queue_Id from Aggr_Queue_Jobs aqj where aqj.Job_Process_Id = '"
        + jobId
        + "' and aqj.Job_Queue_Id = (select max(mx.Job_Queue_Id) from Aggr_Queue_Jobs mx where mx.Job_Process_Id = aqj.Job_Process_Id)"
    )
    queueId = mf.getOracleSql(oraInst, oraUser, oraPass, queueIdSql).iloc[0][
        "JOB_QUEUE_ID"
    ]
    # print(jobStatus)
    if queueId == "":
        exit("Job Id: " + jobId + ". Queue Id not found!\n")
    return queueId


def getJobLogs(jobId, startTime):
    global logDir, memoryHash, oraInst, oraUser, oraPass
    jobLogSql = (
        """select l.process_id,
							l.log_id,
							l.process_name,
							l.message,
							to_char(logged_at,'mm/dd/yyyy HH:MI:SS') as logged_at
							from log_messages l where l.process_type='PRPL'
							and l.process_id='"""
        + jobId
        + """'
							and to_char(logged_at,'yyyymmdd') >= '"""
        + startTime.strftime("%Y%m%d")
        + """'
							order by logged_at"""
    )
    # startTime.strftime("%Y%m%d")
    # print(jobLogSql)
    jdf = mf.getOracleSql(oraInst, oraUser, oraPass, jobLogSql)
    sfh = open(logDir + "/buildPriStatusLog.txt","r")
    sfhHeader = sfh.readline()
    sfh.close
    sfh = open(logDir + "/buildPriStatusLog.txt","w")
    sfh.write(sfhHeader)
    if not jdf.empty:
        for i, row in jdf.iterrows():
            logId = str(row["LOG_ID"])
            processName = row["PROCESS_NAME"]
            message = row["MESSAGE"]
            loggedAt = str(row["LOGGED_AT"])
            sfh.write(
                "Log_Id: "
                + logId
                + ". Process_Name: "
                + processName
                + ". Message: "
                + message
                + ". Logged_At: "
                + loggedAt
                + ".\n"
            )
    sfh.close()

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
