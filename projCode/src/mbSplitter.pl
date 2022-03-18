#!/usr/bin/perl -w
#Includes
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Cwd;
my $scriptDir;
my $libDir;
my $aggrDir;
my $envName;
my $codeDir;
my $scatterDir;
BEGIN
{
   $scriptDir = Cwd::abs_path(dirname($0));
	my $lib = dirname($scriptDir);
	if($lib =~ m/mv_utilities/)
	{
		$codeDir = $lib . "/src";
		$lib =~ s/mv_utilities.*/perl_utilities/;
		$libDir = Cwd::abs_path($lib) . "/lib";
		$aggrDir = Cwd::abs_path($lib) . "/aggr";
		$scatterDir = Cwd::abs_path($lib) . "/scripts/scatterQC/customQA";
	}
	else
	{
		$lib = `conda info -e | grep '*'`;
		$lib =~ s/^.*\*//;
		$lib =~ s/^\s+|\s+$//g;
		my $sitePath = `python -m site | grep $lib | grep -P "site-packages'"`;
		$sitePath =~ s/^\s+|\s+$//g;
		$sitePath =~ s/('|,)//g;
		$libDir = $sitePath . "/lib";
		$aggrDir = $sitePath . "/aggr";
		$codeDir = $sitePath . "/projCode/src";
		$scatterDir = $sitePath . "/scripts/scatterQC/customQA";
	}
	$envName = `conda info -e | grep '*'`;
	$envName =~ s/\*.*//;
	$envName =~ s/^\s+|\s+$//g;
}
use lib $libDir;
use MiscFunctions;

#driver script to run set up for AB/CPM, create the directories for each 
#setting, copy bucket.txt and donotproject.txt from prior month, 
#and run one of four phases: Projections, QC, Buildmigrations, or Checkmigrations

#usage:
#perl mbSplitter.pl
#run from this months project directory

#before kicking off mbSplitter.pl, need to do following steps:
#1)create config directory, copy settings.cfg from prior month config dir
#
#2)change vintage and job id (aggr id) in settings.cfg to whatever should 
#  be used this month
#note: the values in runinputs.txt have been consolidated into config/settings.cfg

#runinputs.txt contain the following info in 2 tab-separated columns
#Parameter	Value
#Client	AB|CPM
#AnalysisType	Projections|QC|Buildmigrations|Checkmigrations
#PrevDir	Location of last month deliverable project directory
#Settings	IP,OP,Freestanding
#PrevMF		Prior month MF Orgfile location
#CurrMF		Current month MF Orgfile location

#note - the above specification of Settings is to do all 3 for AB
# all 4 for CPM would read IP,OP,OfficeASC,SNF
# to do any subset of them, just leave out the ones you don't want

#note2 - Buildigrations and Checkmigrations only relevant for AB
#  - PrevMF and CurrMF only needed for Buildmigrations and Checkmigrations

my @ogArgs = @ARGV;
$| = 1;

my $timeBegin = time();

my $config;
my $debug;

GetOptions(
	"config=s"  =>\$config,
	"debug"     =>\$debug
);

die "-config parameter is required\n" unless $config;
print Dumper(@ogArgs) if $debug;

my $settingVars = MiscFunctions::createSettingHash(config=>$config);
my $memoryHash;
my $qcScript = $scatterDir . "/ABCPM_monthlyQC.R";
my $logDir = "logFiles";
my $oraUser = "claims_aggr";
my $oraPass = "Hydr0gen2014";
my $oraInst = "PLDWH2DBR";

#verify settingVars
foreach my $x (qw/VINTAGE USERNAME PASSWORD INSTANCE AGGREGATION_TABLE CLAIM_PATIENT_TABLE CLIENT ANALYSIS_TYPE PREV_DIR SETTINGS/)
{
	die $x . "=> parameter is required\n" unless defined $settingVars->{$x}[0] && $settingVars->{$x}[0] ne "NULL";
}
die "CLIENT must be either AB or CPM\n" unless $settingVars->{"CLIENT"}[0] =~ m/(^AB$|^CPM$)/;
die "ANALYSIS_TYPE must be one of the following values: Aggr|Projections|QC|Buildmigrations|Checkmigrations\n" unless $settingVars->{"ANALYSIS_TYPE"}[0] =~ m/(^Aggr$|^Projections$|^QC$|^Buildmigrations$|^Checkmigrations$)/;
die "ANALYSIS_TYPE cannot be '" . $settingVars->{"ANALYSIS_TYPE"}[0] . "' if CLIENT is not AB\n" if $settingVars->{"ANALYSIS_TYPE"}[0] =~ m/(^Buildmigrations$|^Checkmigrations$)/ && $settingVars->{"CLIENT"}[0] ne "AB";
if($settingVars->{"ANALYSIS_TYPE"}[0] ne "Aggr")
{
	die "JOB_ID=> parameter is required\n" unless defined $settingVars->{"JOB_ID"}[0] && $settingVars->{"JOB_ID"}[0] ne "NULL";
}
else
{
	if($settingVars->{"CLIENT"}[0] eq "AB")
	{
		die "ANALYSIS_TYPE=> second parameter required (Old|New)\n" unless defined $settingVars->{"ANALYSIS_TYPE"}[1] && $settingVars->{"ANALYSIS_TYPE"}[1] =~ m/(^Old$|^New$)/;
	}
}

if($settingVars->{"ANALYSIS_TYPE"}[0] =~ m/(^Buildmigrations$|^Checkmigrations$)/)
{
	foreach my $x (qw/PREV_MF CURR_MF/)
	{
		die "Analysis_Type: " . $settingVars->{"ANALYSIS_TYPE"}[0] . " is chosen and " . $x . " is undefined\n" unless defined $settingVars->{$x}[0] && $settingVars->{$x}[0] ne "NULL";
		die $x . " file not found: " . $settingVars->{$x}[0] . "\n" unless -e $settingVars->{$x}[0];
	}
}

foreach my $x (@{$settingVars->{"SETTINGS"}})
{
	die "Bad SETTINGS value: " . $x unless $x =~ m/(^IP$|^OP$|^Freestanding$|^OfficeASC$|^SNF$)/;
}

#Set the location of the migrations-related scripts
my $migDir = $codeDir . "/AdvisoryBoard";

#Write vars to more user-friendly values
my $client = $settingVars->{"CLIENT"}[0];
my $analysisType = $settingVars->{"ANALYSIS_TYPE"}[0];
my $prevDir = $settingVars->{"PREV_DIR"}[0];
my $vintage = $settingVars->{"VINTAGE"}[0];
$vintage = MiscFunctions::normalizeDate(date=>$vintage,yyyymmdd=>"Y");
my $instance = $settingVars->{"INSTANCE"}[0];
my $username = $settingVars->{"USERNAME"}[0];
my $password = $settingVars->{"PASSWORD"}[0];
my @settings = @{$settingVars->{"SETTINGS"}};
my $prevMF = $settingVars->{"PREV_MF"}[0];
my $currMF = $settingVars->{"CURR_MF"}[0];

if($analysisType eq "Aggr")
{
	my $clientJob = $client eq "AB" ? $client . "_" . $settingVars->{"ANALYSIS_TYPE"}[1] : $client;
	print "Building " . $clientJob . " aggregations...\n";
	my $date = substr($vintage,0,6);
	$date++;
	my @months = qw/Nul Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec Jan/;
	my $newDate;
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
	$mon++;
	$year += 1900;
	my ($schedulerJobName,$aggrSql,$jobIdSql);
	if($client eq "AB")
	{
		$newDate = substr($date,0,4) . $months[substr($date,4,2)];
		my $states = $settingVars->{"ANALYSIS_TYPE"}[1];
		my $refreshSql = "Begin
									update avb_vendors set job_status='PENDING' where last_vend_date > 18000102;
									update avb_vendors_states set job_status='PENDING' where last_vend_date > 18000102;
									update avb_vendors set last_vend_date=20010102 where job_status='PENDING';
									update avb_vendors_states set last_vend_date=20010102 where job_status='PENDING';
									commit;
								End;";
		MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,sql=>$refreshSql,quiet=>"Y");
		if($states eq "New")
		{
			$schedulerJobName = join("_","AVB",$newDate,"newstates",$year . $mon . $mday,$hour,$min);
			$aggrSql = "Begin
								dbms_scheduler.create_job
								(
									job_name => '" . $schedulerJobName . "',
									job_type => 'PLSQL_BLOCK',
									job_action => 'Declare l_vintage_dt	NUMBER := " . $vintage . ";
																	l_job_name_suffix  VARCHAR2(80) := ''" . $newDate . "newstates'';
														Begin
															Claims_aggr.Pkg_Aggr_Util_avbstates.Kick_Off_Custom_Aggrs(
																p_Xwalk_Date => l_vintage_dt,
																p_Job_Name_Suffix => l_job_name_suffix
															);
															Claims_aggr.Pkg_Avb_Trending.Run_All;
															Claims_aggr.pkg_avb_trending.Create_Trending_Table(p_Vintage_Name => ''DDB_''||l_vintage_dt);
														End;',
									start_date => sysdate,
									enabled => TRUE,  
									auto_drop => TRUE,
									comments => 'one-time job'
								);
							end;";
			$jobIdSql = "select max(job_id) as job_id from pxdx_jobs t where t.job_type = 'AVB' and t.job_name = 'AVB " . $newDate . "newstates'";
		}
		elsif($states eq "Old")
		{
			$schedulerJobName = join("_","AVB",$newDate,"oldstates",$year . $mon . $mday,$hour,$min);
			$aggrSql = "Begin
								dbms_scheduler.create_job
								(
									job_name => '" . $schedulerJobName . "',
									job_type => 'PLSQL_BLOCK',
									job_action => 'Declare l_vintage_dt NUMBER := " . $vintage . ";
																	l_job_name_suffix  VARCHAR2(80) := ''" . $newDate . "oldstates'';
														Begin
															Claims_aggr.Pkg_Aggr_Util.Kick_Off_Custom_Aggrs(
																p_Xwalk_Date => l_vintage_dt,
																p_Job_Name_Suffix => l_job_name_suffix
															);
															End;',
									start_date => sysdate,
									enabled => TRUE,  
									auto_drop => TRUE,
									comments => 'one-time job'
								);
							end;";
			$jobIdSql = "select max(job_id) as job_id from pxdx_jobs t where t.job_type = 'AVB' and t.job_name = 'AVB " . $newDate . "oldstates'";
		}
		MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,sql=>$aggrSql,quiet=>"Y");
		print "\tAggregation started. SchedulerJobName: " . $schedulerJobName . "...\n";
		#Wait for the job to finish
		my $status = getJobStatus(schedulerJobName=>$schedulerJobName);
		while($status)
		{
			sleep 60;
			$status = getJobStatus(schedulerJobName=>$schedulerJobName);
		}
		my @jidKey = qw/JOB_ID/;
		$memoryHash->{"AVB_STATES_JID"} = MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,oraDataKey=>\@jidKey,sql=>$jobIdSql,quiet=>"Y");
		my $jobId;
		foreach my $x (keys %{$memoryHash->{"AVB_STATES_JID"}})
		{
			$jobId = $x;
		}
		#update Job_Vendors for oldstates
		if($states eq "Old")
		{
			my $updateJVSql = "Begin
										update job_vendors set first_vend_date = 20140101, last_vend_date = 20141231 where job_id = " . $jobId . " and vendor_id in (11,12,13);
										update job_vendors set first_vend_date = 20130101, last_vend_date = 20131231 where job_id = " . $jobId . " and vendor_id in (20,21);
										update job_vendors set first_vend_date = 18000102, last_vend_date = 18000101 where job_id = " . $jobId . " and vendor_type = 'ABSTATE';
										commit;
									End;";
			print "\t\tUpdating Job_Vendors for " . $clientJob . " Aggregation...";
			MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,sql=>$updateJVSql,quiet=>"Y");
			print "done\n";
		}
		refreshCfg(jobId=>$jobId);
		print "\tAggregation finished. Produced Job_Id: " . $jobId . "\n";
	}
	elsif($client eq "CPM")
	{
		#CPM has 2 deliverables, a normal splitter, and an enhanced with Emdeon. The initiate package generates the two job IDs, and the execute package creates the aggregations
		#Running aggregations will assume you are building off normal, and generate a config directory for the Enhanced
		$newDate = $months[substr($date,4,2)] . substr($date,0,4);
		$schedulerJobName = join("_","CPM",$newDate,$year . $mon . $mday,$hour,$min);
		my $initSql = "Declare t number;
								Begin
									t:= claims_aggr.pkg_cpm_aggr_pxdx.Initiate_Cpm(
										p_Xwalk_Dt =>'" . join("-",substr($vintage,6,2),$months[substr($date,4,2)-1],$year) . "', p_Job_Nm =>'" . $months[substr($date,4,2)] . $year . " Deliverable');
										dbms_output.put_line(t);
									End;";
		MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,sql=>$initSql,quiet=>"Y");
		$jobIdSql = "select max(job_id) as job_id from pxdx_jobs t where t.job_type = 'CPM' and t.job_name = '" . $months[substr($date,4,2)] . $year . " Deliverable'";
		my $emdeonJobIdSql = "select max(job_id) as job_id from pxdx_jobs t where t.job_type = 'CPM' and t.job_name = '" . $months[substr($date,4,2)] . $year . " Deliverable with emdeon'";
		my @jidKey = qw/JOB_ID/;
		$memoryHash->{"CPM_JID"} = MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,oraDataKey=>\@jidKey,sql=>$jobIdSql,quiet=>"Y");
		$memoryHash->{"CPM_EJID"} = MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,oraDataKey=>\@jidKey,sql=>$emdeonJobIdSql,quiet=>"Y");
		my ($jobId,$eJobId);
		foreach my $x (keys %{$memoryHash->{"CPM_JID"}})
		{
			$jobId = $x;
		}
		foreach my $x (keys %{$memoryHash->{"CPM_EJID"}})
		{
			$eJobId = $x;
		}
		$aggrSql = "Begin
							dbms_scheduler.create_job
							(
								job_name => '" . $schedulerJobName . "',
								job_type => 'PLSQL_BLOCK',
								job_action => 'Begin claims_aggr.pkg_cpm_aggr_pxdx.Execute_Cpm(p_Job_Id =>" . $jobId . "); End;',
								start_date => sysdate,
								enabled => TRUE,  
								auto_drop => TRUE,
								comments => 'one-time job'
							);
						end;";
		MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,sql=>$aggrSql,quiet=>"Y");
		print "\tAggregation started. SchedulerJobName: " . $schedulerJobName . "...\n";
		#Wait for the job to finish
		my $status = getJobStatus(schedulerJobName=>$schedulerJobName);
		while($status)
		{
			sleep 60;
			$status = getJobStatus(schedulerJobName=>$schedulerJobName);
		}
		refreshCfg(jobId=>$jobId);
		my $month = sprintf("%02d",$mon);
		my $eDir = join("_",$year,$month,"15","PxDx","Enhanced");
		system("mkdir","-p",$eDir);
		system("cp","-r","config",$eDir);
		my $currDir = `pwd`;
		$currDir = MiscFunctions::cleanLine(line=>$currDir);
		chdir($eDir);
		refreshCfg(jobId=>$eJobId,updatePrevDir=>"Y");
		chdir($currDir);
		print "\tAggregation finished. Produced Job_Id: " . $jobId . ", and Enhanced Job_Id: " . $eJobId . "\n";
	}
	print "done\n";
}
elsif($analysisType eq "Projections")
{
	my $hgRoot = "/vol/cs/clientprojects/mv_utilities/projCode";
	if($settingVars->{"FXFILES"}[0] ne "NULL" && $settingVars->{"FXFILES"}[0] =~ m/\//)
	{
		die "FXFILES has a '/' character. FXFILES cannot be a path and must be a suffix or null. run_ABCPM quitting\n";
	}
	if(lc($settingVars->{"FXFILES"}[0]) eq "master")
	{
		die "FXFILES cannot be set to master\n";
	}
	
	my $fxFiles = $hgRoot . "/";
	if($settingVars->{"FXFILES"}[0] eq "NULL")
	{
		$fxFiles .= "InputDataFiles/" . $envName;
	}
	else
	{
		$fxFiles .= "InputDataFiles/" . $settingVars->{"FXFILES"}[0];
	}
	my $jobId = $settingVars->{"JOB_ID"}[0];
	my $aggrTable = $settingVars->{"AGGREGATION_TABLE"}[0];
	
	open my $iofh, ">", "input.txt";
	print $iofh "Parameter\tValue\n";
	print $iofh "VINTAGE\t" . $vintage . "\n";
	print $iofh "FXFILES\t" . $fxFiles . "\n";
	print $iofh "INSTANCE\t" . $instance . "\n";
	print $iofh "USERNAME\t" . $username . "\n";
	print $iofh "PASSWORD\t" . $password . "\n";
	print $iofh "AGGREGATION_ID\t" . $jobId . "\n";
	print $iofh "AGGREGATION_TABLE\t" . $aggrTable . "\n";
	print $iofh "COUNTTYPE\tCLAIM\n";
	print $iofh "CODETYPE\t" . $client . "\n";
	print $iofh "AddRefDoc\tN\n";
	print $iofh "Filter1500Specialty\tN\n";
	close $iofh;
	
	#make sure Fx Files directory is set up properly
	system("mkdir","-p",$fxFiles);
	my @reqFiles = qw/aha_demo.sas7bdat covar_under65.sas7bdat covar_county_unemp.sas7bdat covar_ma_penetration.sas7bdat covar_hi_expend.sas7bdat CMS_ASC_ProcedureData.txt HospitalExclusionList.tab ins_mapenet.sas7bdat test_u65byhsa.sas7bdat zip2fips.sas7bdat/;
	print $fxFiles . "\n";
	foreach my $x (@reqFiles)
	{
		unless(-e $fxFiles . "/" . $x)
		{
			system("cp " . $hgRoot . "/InputDataFiles/master/" . $x . " " . $fxFiles . "/" . $x);
		}
	}
	
	#run createxwalks
	my $cxwStatus = system("createxwalks.py &> /dev/null");
	die "createxwalks finished with non-zero exit code: " . $cxwStatus . ". run_ABCPM quitting.\n" unless $cxwStatus == 0;
	
	#loop through settings:
	foreach my $x (@settings)
	{
		print "Building " . $x . " Projections...\n";
		my $mbTimeBegin = time();
		system("mkdir","-p",$x);
		my $pbFile;
		if(defined $settingVars->{"BUCKET_PATH"}[0] && $settingVars->{"BUCKET_PATH"}[0] ne "NULL")
		{
			my $bucketPath = $settingVars->{"BUCKET_PATH"}[0];
			$pbFile = -e $bucketPath ? $bucketPath : die "BUCKET_PATH not found: " . $bucketPath . "\n";
		}
		else
		{
			$pbFile = $prevDir . "/" . $x . "/buckets.txt";
		}
		my $pdnpFile = $prevDir . "/" . $x . "/donotproject.txt";
		system("cp " . $pbFile . " " . $x);
		system("cp " . $pdnpFile . " " . $x) if -e $pdnpFile;
		
		#cd into each setting, build projections, and navigate back up
		chdir($x);
		runMB(setting=>$x,vintage=>$vintage);
		#cleanup sas files
		unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
		{
			system("rm -f *sas7*");
		}
		my $mbTimeEnd = time();
		print "Building " . $x . " Projections Complete\n";
		my $mbRunTime = $mbTimeEnd - $mbTimeBegin;
		my $mbMinutes = $mbRunTime/60;
		print "Job took " . $mbMinutes . " minutes\n";
		chdir("..");
	}
	
	unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
	{
		system("rm -f *sas7*");
	}
}
elsif($analysisType eq "QC")
{
	#create the proj-level input file compinput.txt
	open my $cofh, ">", "compinput.txt";
	print $cofh "Parameter\tValue\n";
	print $cofh "PrevDir\t" . $prevDir . "\n";
	print $cofh "Vintage\t" . $vintage . "\n";
	print $cofh "DBInstance\t" . $instance . "\n";
	print $cofh "DBUsername\t" . $username . "\n";
	print $cofh "DBPassword\t" . $password . "\n";
	close $cofh;
	
	#Go into each setting and run the QC R script if setting and result exists
	foreach my $x (@settings)
	{
		print "Running " . $x . " QC...";
		if(-e $x)
		{
			chdir($x);
			if(-e "pxdxresult.txt")
			{
				my $qcTimeBegin = time();
				system("R CMD BATCH --vanilla " . $qcScript);
				my $qcTimeEnd = time();
				my $qcRunTime = $qcTimeEnd - $qcTimeBegin;
				my $qcMinutes = $qcRunTime/60;
				print "done. Job took " . $qcMinutes . " minutes\n";
			}
			else
			{
				print "pxdxresult.txt not found, skipping QC\n";
			}
			chdir("..");
		}
		else
		{
			print "setting directory not found, skipping QC\n";
		}
	}
}
elsif($analysisType eq "Buildmigrations")
{
	#create the compinput.txt file needed for migrations
	open my $cofh, ">", "compinput.txt" or die "cant create compinput.txt\n";
	print $cofh "Parameter\tValue\n";
	print $cofh "PrevMF\t" . $prevMF . "\n";
	print $cofh "CurrMF\t" . $currMF . "\n";
	close $cofh;
	
	#CHANGE 20181207 - create cleaned_migrations.tab file (which will now sit in project directory) from CurrMF migrations 
	#Create the name of the dirty migrations file from the CurrMF and call perl code to clean migrations
	my @currMFDirs = split("\/",$currMF);
	my $currMFClean = join("\/",@currMFDirs[0 .. ($#currMFDirs-2)]);
	my $migUniqueFile = $currMFClean . "/migration_unique.tab";
	cleanMig(migUniq=>$migUniqueFile);
	my $cleanMigFile = "cleaned_migrations.tab";
	
	#go into each setting and run the build migr steps if setting and result exists
	foreach my $x (@settings)
	{
		print "Running " . $x . " Buildmigrations...";
		if(-e $x)
		{
			chdir($x);
			if(-e "poidvolcomp.txt")
			{
				my $bmTimeBegin = time();
				system("ln -s ../" . $cleanMigFile);
				system("R CMD BATCH --vanilla " . $migDir . "/buildmigrations_v2.R");
				system("cp migrations_candidates.txt namebased_migrations.txt"); #comment this when testing is done
				my $bmTimeEnd = time();
				my $bmRunTime = $bmTimeEnd - $bmTimeBegin;
				my $bmMinutes = $bmRunTime/60;
				print "done. Job took " . $bmMinutes . " minutes\n";
			}
			else
			{
				print "poidvolcomp.txt not found, skipping Buildmigrations\n";
			}
			chdir("..");
		}
		else
		{
			print "setting directory not found, skipping Buildmigrations\n";
		}
	}
}
elsif($analysisType eq "Checkmigrations")
{
	#create the compinput.txt file needed for migrations
	open my $cofh, ">", "compinput.txt";
	print $cofh "Parameter\tValue\n";
	print $cofh "PrevMF\t" . $prevMF . "\n";
	print $cofh "CurrMF\t" . $currMF . "\n";
	close $cofh;
	
	#go into each setting and run the build migr steps if setting and result exists
	foreach my $x (@settings)
	{
		print "Running " . $x . " Checkmigrations...";
		if(-e $x)
		{
			chdir($x);
			if(-e "namebased_migrations.txt")
			{
				my $cmTimeBegin = time();
				combMig();
				system("R CMD BATCH --vanilla " . $migDir . "/checkmigr.R");
				system("R CMD BATCH --vanilla " . $migDir . "/createmigratedpoidgraph.R");
				my $cmTimeEnd = time();
				my $cmRunTime = $cmTimeEnd - $cmTimeBegin;
				my $cmMinutes = $cmRunTime/60;
				print "done. Job took " . $cmMinutes . " minutes\n";
			}
			else
			{
				print "namebased_migrations.txt not found, skipping Checkmigrations\n";
			}
			chdir("..");
		}
		else
		{
			print "setting directory not found, skipping Checkmigrations\n";
		}
	}
}

my $subject = "run_ABCPM Job: \"" . $analysisType . "\" complete";
my $message = "Your run_ABCPM Job is finished running.\n" .
	"\tClient: " . $client . "\n" .
	"\tAnalysisType: " . $analysisType . "\n" .
	"\tRun Location: " . `pwd` . "\n";
MiscFunctions::sendEmail(subject=>$subject,message=>$message);

system("chmod 777 -R --silent .");

my $timeEnd = time();

my $runTime = $timeEnd - $timeBegin;
print "\nProcess Complete: " . $0 . "\n";
my $minutes = $runTime/60;
print "Job took " . $minutes ." minutes\n";

sub refreshCfg
{
	my %args = @_;
	my $jobId = $args{jobId} || die "jobId=> parameter is required\n";
	my $updatePrevDir = $args{updatePrevDir} || "";
	
	my $vintage = $settingVars->{"VINTAGE"}[0] ne "NULL" ? $settingVars->{"VINTAGE"}[0] : "";
	my $username = $settingVars->{"USERNAME"}[0] ne "NULL" ? $settingVars->{"USERNAME"}[0] : "";
	my $password = $settingVars->{"PASSWORD"}[0] ne "NULL" ? $settingVars->{"PASSWORD"}[0] : "";
	my $instance = $settingVars->{"INSTANCE"}[0] ne "NULL" ? $settingVars->{"INSTANCE"}[0] : "";
	my $aggrTable = $settingVars->{"AGGREGATION_TABLE"}[0] ne "NULL" ? $settingVars->{"AGGREGATION_TABLE"}[0] : "";
	my $claimPatTable = $settingVars->{"CLAIM_PATIENT_TABLE"}[0] ne "NULL" ? $settingVars->{"CLAIM_PATIENT_TABLE"}[0] : "";
	my $fxFiles = $settingVars->{"FXFILES"}[0] ne "NULL" ? $settingVars->{"FXFILES"}[0] : "";
	my $preserveSas = $settingVars->{"PRESERVE_SAS"}[0] ne "NULL" ? $settingVars->{"PRESERVE_SAS"}[0] : "";
	my $client = $settingVars->{"CLIENT"}[0] ne "NULL" ? $settingVars->{"CLIENT"}[0] : "";
	my $analysisType = $settingVars->{"ANALYSIS_TYPE"}[0] ne "NULL" ? join(" ", @{$settingVars->{"ANALYSIS_TYPE"}}) : "";
	my $prevDir = $settingVars->{"PREV_DIR"}[0] ne "NULL" ? $settingVars->{"PREV_DIR"}[0] : "";
	if($updatePrevDir)
	{
		die "Cannot update null PREV_DIR variable\n" if $prevDir eq "";
		$prevDir =~ s/\/$//;
		$prevDir .= "_Enhanced/";
		#since this option is specifically for updating the CPM Enhanced cfg file, set analysisType to Projections so you don't accidentally re-run CPM aggregations in the Enhanced version
		$analysisType = "Projections";
	}
	my $settings = $settingVars->{"SETTINGS"}[0] ne "NULL" ? join(" ",@{$settingVars->{"SETTINGS"}}) : "";
	my $bucketPath = $settingVars->{"BUCKET_PATH"}[0] ne "NULL" ? $settingVars->{"BUCKET_PATH"}[0] : "";
	my $prevMF = $settingVars->{"PREV_MF"}[0] ne "NULL" ? $settingVars->{"PREV_MF"}[0] : "";
	my $currMF = $settingVars->{"CURR_MF"}[0] ne "NULL" ? $settingVars->{"CURR_MF"}[0] : "";
	
	my $cfg = "config";
	system("mkdir","-p",$cfg . "/logFiles");
	open my $lofh, ">>", $cfg . "/logFiles/avbJobLogs.txt";
	print $lofh $client . " aggregations generated with Job_Id: " . $jobId . "\n";
	close $lofh;
	
	open my $cfh, ">", $cfg . "/settingsNew.cfg";
	print $cfh "#-------------PxDx_Jobs settings-------------\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Can be of form yyyymmdd or mm/dd/yyyy or yyyy_mm_dd\n";
	print $cfh "VINTAGE = " . $vintage . "\n";
	print $cfh "\n";
	print $cfh "# JOB_ID\n";
	print $cfh "JOB_ID = " . $jobId . "\n";
	print $cfh "\n";
	print $cfh "#-------------Oracle settings-------------\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Username for the claims database. 99% of the time you should NOT change this\n";
	print $cfh "USERNAME = " . $username . "\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Password for the claims database. 99% of the time you should NOT change this\n";
	print $cfh "PASSWORD = " . $password . "\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Instance for the claims database. 99% of the time you should NOT change this\n";
	print $cfh "INSTANCE = " . $instance . "\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Aggregation Table for the Aggregation process. 99% of the time you should NOT change this\n";
	print $cfh "AGGREGATION_TABLE = " . $aggrTable . "\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Claim Patient Table for the Aggregation process. 99% of the time you should NOT change this\n";
	print $cfh "CLAIM_PATIENT_TABLE = " . $claimPatTable . "\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Location of FXFiles. 99% of the time you should NOT change this\n";
	print $cfh "FXFILES = " . $fxFiles . "\n";
	print $cfh "\n";
	print $cfh "# OPTIONAL: Flag for if you want to preserve your sas databases. \"Y\" to enable, all other values will default to cleaning up sas files\n";
	print $cfh "PRESERVE_SAS =	" . $preserveSas . "\n";
	print $cfh "\n";
	print $cfh "#-------------Run_Inputs settings-------------\n";
	print $cfh "# REQUIRED: Client you are running multiBucketSplitter for (AB|CPM)\n";
	print $cfh "CLIENT = " . $client . "\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: What phase of multiBucketSplitter you want to run (Aggr|Projections|QC). For AB (Buildmigrations|Checkmigrations). If Aggr and AB, also supply Old|New\n";
	print $cfh "ANALYSIS_TYPE = " . $analysisType . "\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Location of Previous deliverable\n";
	print $cfh "PREV_DIR = " . $prevDir . "\n";
	print $cfh "\n";
	print $cfh "# REQUIRED: Settings you wish to build (IP|OP|Freestanding|OfficeASC|SNF)\n";
	print $cfh "SETTINGS = " . $settings . "\n";
	print $cfh "\n";
	print $cfh "# OPTIONAL: Location of an alternate bucket file. If you want to run a subset of the normal buckets\n";
	print $cfh "BUCKET_PATH = " . $bucketPath . "\n";
	print $cfh "\n";
	print $cfh "# OPTIONAL: Location of Previous MasterFile (Used for Buildmigrations)\n";
	print $cfh "PREV_MF = " . $prevMF . "\n";
	print $cfh "\n";
	print $cfh "# OPTIONAL: Location of Current MasterFile (Used for Buildmigrations)\n";
	print $cfh "CURR_MF = " . $currMF . "\n";
	close $cfh;
	system("mv " . $cfg . "/settingsNew.cfg " . $cfg . "/settings.cfg");
}

sub getJobStatus
{
	my %args = @_;
	my $schedulerJobName = $args{schedulerJobName} || die "schedulerJobName=> parameter is required\n";
	my $jobStatusSql = "select * from user_scheduler_jobs t where t.job_name = '" . uc($schedulerJobName) . "'";
	my @jobStatusKey = qw/JOB_NAME/;
	my $jobStatusRaw = MiscFunctions::getOracleSql(oraInstance=>$oraInst,oraUser=>$oraUser,oraPass=>$oraPass,sql=>$jobStatusSql,oraDataKey=>\@jobStatusKey,quiet=>"Y",dontDie=>"Y") || -1;
	if($jobStatusRaw == -1)
	{
		return 0;
	}
	else
	{
		return 1;
	}
}

sub runMB
{
	#sub to build projections for each setting
	my %args = @_;
	my $setting = $args{setting} || die "setting=> parameter is required\n";
	my $vintage = $args{vintage} || die "vintage=> parameter is required\n";
	my $currDir = `pwd`;
	
	my $counter = 0;
	
	open my $bifh, "<", "buckets.txt";
	my $header = <$bifh>;
	while(my $line = <$bifh>)
	{
		$line = MiscFunctions::cleanLine(line=>$line);
		my @entry = split("\t",$line);
		$memoryHash->{"BUCKETS"}->{$setting}->{$entry[0]} = 1;
	}
	close $bifh;
	if(-e "donotproject.txt")
	{
		my @dnpKey = qw/BUCKET/;
		$memoryHash->{"DNP_BUCKETS"}->{$setting} = MiscFunctions::fillDataHashes(file=>"donotproject.txt",hashKey=>\@dnpKey);
		MiscFunctions::fillDataHashes(file=>"donotproject.txt",hashKey=>\@dnpKey);
	}
	my $aggrTable = $settingVars->{"AGGREGATION_TABLE"}[0];
	foreach my $x (qw/pxdxresult.txt pxdxresultnostar.txt pxdxresult_nostar.txt *.log *.lst/)
	{
		unless($setting eq "SNF" && ($x =~ m/(log|lst)/))
		{
			system("rm -f " . $x);
		}
	}
	
	my ($snfstofh,$snfnoofh);
	if($setting eq "SNF")
	{
		open $snfstofh, ">", "pxdxresult.txt";
		open $snfnoofh, ">", "pxdxresultnostar.txt";
		my @snfOutHeader = qw/Bucket HMS_PIID HMS_POID PractFacProjCount FacProjCount/;
		print $snfstofh join("\t",@snfOutHeader) . "\n";
		print $snfnoofh join("\t",@snfOutHeader) . "\n";
	}
	
	#iterate through buckets for your given setting
	foreach my $x (keys %{$memoryHash->{"BUCKETS"}->{$setting}})
	{
		#$next if $counter >= 10;
		#next unless $x eq "0";
		print "\tBuilding " . $x . "...";
		my $bucketName = $x;
		$bucketName =~ s/(\s+|\/|\(|\))//g;
		
		#copy parent input file and append setting specific options
		system("cp ../input.txt .");
		open my $iofh, ">>", "input.txt";
		print $iofh "BUCKET\t$x\n";
		#write DNP related values to input.txt
		if(defined $memoryHash->{"DNP_BUCKETS"}->{$setting}->{$x})
		{
			if($setting eq "IP")
			{
				print $iofh "PROJECTIP\tN\n";
			}
			elsif($setting eq "OP")
			{
				print $iofh "PROJECTOP\tN\n";
			}
			elsif(($setting eq "Freestanding") || ($setting eq "OfficeASC"))
			{
				print $iofh "PROJECTOFF\tN\n";
				print $iofh "PROJECTASC\tN\n";
				print $iofh "PROJECTLAB\tN\n" if $setting eq "Freestanding";
			}
			elsif($setting eq "SNF")
			{
				print $iofh "PACSettings\tSNF\n";
			}
		}
		close $iofh;
		
		#symlink files as appropriate
		if($setting =~ m/(^IP$|^OP$|^OfficeASC$|^Freestanding$)/)
		{
			my @symlinkFiles = ();
			push(@symlinkFiles,qw/cms_poidlist ip_datamatrix poid_volume state_poidlist wk_poidlist poid_attributes_ip/) if $setting eq "IP";
			push(@symlinkFiles,qw/op_datamatrix poid_attributes_op op_poids asc_datamatrix/) if $setting eq "OP";
			push(@symlinkFiles,qw/asc_datamatrix/) if $setting eq "OfficeASC" || $setting eq "Freestanding";
			foreach my $y (@symlinkFiles)
			{
                unless(-e $y . ".sas7bdat")
                {
                    system("ln -s ../" . $y . ".sas7bdat .");
                }
			}
		}
		
		system("mkdir","-p",$logDir);
		
		runIPProjections(bucket=>$x,bucketName=>$bucketName) if $setting eq "IP";
		runOPProjections(bucket=>$x,bucketName=>$bucketName) if $setting eq "OP";
		runFSProjections(bucket=>$x,bucketName=>$bucketName,setting=>$setting) if $setting eq "Freestanding" || $setting eq "OfficeASC";
		runSNFProjections(bucket=>$x,bucketName=>$bucketName,starHandle=>$snfstofh,noStarHandle=>$snfnoofh) if $setting eq "SNF";
		$counter++;
		
		#clean bucket
		foreach my $y (qw/asc_projections.txt asc_projections_wb.txt freestanding_projections.txt freestanding_projections_nostar.txt hospital_projections.txt hospital_projections_nostar.txt input.txt lab_proj.log lab_proj_debug.log lab_projection.txt lab_projections_wb.txt office_asc_projections.txt office_asc_projections_nostar.txt office_projections.txt office_projections_wb.txt project_ASC.log project_ASC.lst project_IP_facility.log project_IP_facility.lst project_IP_Practitioner.log project_Office.log project_Office.lst project_OP.log project_OP.lst *sas7bdat*/)
		{
			if($y eq "*sas7bdat*")
			{
				unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
				{
					unless($setting eq "SNF")
					{
						system("rm -f " . $y);
					}
				}
			}
			else
			{
				system("rm -f " . $y);
			}
		}
	}
	
	#post batch projection steps
	if($setting eq "IP")
	{
		my @bucketKey = qw/BUCKET/;
		foreach my $x (qw/IP_Med_Fraction projectip/)
		{
			if(-e $x . "_Final.txt")
			{
				system("mv " . $x . "_Final.txt " . $x . ".txt");
				my @sf = qw/BUCKET/;
				my @ss = ("");
				MiscFunctions::sortTable(file=>$x . ".txt",sortFields=>\@sf,sortStyle=>\@ss);
			}
		}
	}
	elsif($setting eq "OP")
	{
		if(-e "overall_factor_Final.txt")
		{
			system("mv overall_factor_Final.txt overall_factor.txt");
			my @sf = qw/BUCKET/;
			my @ss = ("");
			MiscFunctions::sortTable(file=>"overall_factor.txt",sortFields=>\@sf,sortStyle=>\@ss);
		}
	}
	elsif($setting eq "SNF")
	{
		close $snfstofh;
		close $snfnoofh;
	}
	
	##output summary stats for each setting
	if($setting =~ m/IP|OP/)
	{
		open my $sofh, ">", "summaryinfo.txt";
		print $sofh join("\t",qw/Bucket Lowpf Medpf Highpf TotalPoids Nobs AllpClCnt CMSClCnt HaveRes/) . "\n";
		foreach my $x (keys %{$memoryHash->{"BUCKET_STATS"}->{$setting}})
		{
			my @outEntry;
			push(@outEntry,$x);
			foreach my $y (qw/LOWPF MEDPF HIGHPF TOTPOIDS NOBS ALLPCL CMSCL HAVERES/)
			{
				push(@outEntry,defined $memoryHash->{"BUCKET_STATS"}->{$setting}->{$x}->{$y} ? $memoryHash->{"BUCKET_STATS"}->{$setting}->{$x}->{$y} : "");
			}
			print $sofh join("\t",@outEntry) . "\n";
		}
		close $sofh;
	}
	if($setting =~ m/OfficeASC|Freestanding/)
	{
		open my $sofh, ">", "summaryinfo.txt";
		my @outHeader = $setting eq "Freestanding"? qw/Bucket OffMedPf OffNobs ASCMedPf ASCNobs LABNobs HaveOffRes HaveASCRes HaveLabRes HaveCombRes/ : qw/Bucket OffMedPf OffNobs ASCMedPf ASCNobs HaveOffRes HaveASCRes HaveCombRes/;
		print $sofh join("\t",@outHeader) . "\n";
		foreach my $x (keys %{$memoryHash->{"BUCKET_STATS"}->{uc($setting)}})
		{
			my @outEntry;
			push(@outEntry,$x);
			foreach my $y (qw/OFFICE ASC/)
			{
				foreach my $z (qw/MEDPF NOBS/)
				{
					push(@outEntry,defined $memoryHash->{"BUCKET_STATS"}->{$y}->{$x}->{$z} ? $memoryHash->{"BUCKET_STATS"}->{$y}->{$x}->{$z} : "");
				}
			}
			if($setting eq "Freestanding")
			{
				push(@outEntry,defined $memoryHash->{"BUCKET_STATS"}->{"LAB"}->{$x}->{"HAVERES"} ? $memoryHash->{"BUCKET_STATS"}->{"LAB"}->{$x}->{"HAVERES"} : "");
			}
			foreach my $y (qw/OFFICE ASC/)
			{
				push(@outEntry,defined $memoryHash->{"BUCKET_STATS"}->{$y}->{$x}->{"HAVERES"} ? $memoryHash->{"BUCKET_STATS"}->{$y}->{$x}->{"HAVERES"} : "");
			}
			if($setting eq "Freestanding")
			{
				push(@outEntry,defined $memoryHash->{"BUCKET_STATS"}->{"LAB"}->{$x}->{"HAVERES"} ? $memoryHash->{"BUCKET_STATS"}->{"LAB"}->{$x}->{"HAVERES"} : "");
			}
			push(@outEntry,defined $memoryHash->{"BUCKET_STATS"}->{$setting}->{$x}->{"HAVERES"} ? $memoryHash->{"BUCKET_STATS"}->{$setting}->{$x}->{"HAVERES"} : "");
			print $sofh join("\t",@outEntry) . "\n";
		}
		close $sofh;
	}
}

sub runIPProjections
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	my $bucketName = $args{bucketName};# || die "bucketName=> parameter is required\n";
	my $lstFile = $logDir . "/" . $bucketName . ".lst";
	my $logFac = $logDir . "/" . $bucketName . "_fac.log";
	my $logInp = $logDir . "/" . $bucketName . "_input.log";
	
	#run IP Projections
	system("sas -noterminal -memsize 4G " . $codeDir . "/project_IP_facility.sas > /dev/null");
	system("sas -noterminal -memsize 4G " . $codeDir . "/project_IP_Practitioner.sas > /dev/null");
	system("cp project_IP_facility.lst " . $lstFile) if(-e "project_IP_facility.lst");
	system("cp project_IP_facility.log " . $logFac) if(-e "project_IP_facility.log");
	system("cp project_IP_Practitioner.log " . $logInp) if(-e "project_IP_Practitioner.log");
	
	foreach my $x (qw/IP_Med_Fraction projectip/)
	{
		if(-e $x . ".txt")
		{
			open my $imfifh, "<", $x . ".txt";
			my $header = <$imfifh>;
			$header = MiscFunctions::cleanLine(line=>$header);
			my $imfofh;
			unless(-e $x . "_Final.txt")
			{
				open $imfofh, ">", $x . "_Final.txt";
				print $imfofh "BUCKET\t" . $header . "\n";
			}
			else
			{
				open $imfofh, ">>", $x . "_Final.txt";
			}
			while(my $line = <$imfifh>)
			{
				$line = MiscFunctions::cleanLine(line=>$line);
				print $imfofh $bucket . "\t" . $line . "\n";
			}
			close $imfifh;
			close $imfofh;
			system("rm " . $x . ".txt");
		}
	}
	
	#collect IP stats from log/lst files
	collectIPStats(bucket=>$bucket);
	
	#save the bucket result if exists, else warn
	if(-e "hospital_projections.txt")
	{
		$memoryHash->{"BUCKET_STATS"}->{"IP"}->{$bucket}->{"HAVERES"} = 1;
		saveResult(inFile=>"hospital_projections.txt",saveFile=>"pxdxresult.txt",clearCol5=>"Y");
		saveResult(inFile=>"hospital_projections_nostar.txt",saveFile=>"pxdxresultnostar.txt",clearCol5=>"Y");
		print "done\n";
	}
	else
	{
		$memoryHash->{"BUCKET_STATS"}->{"IP"}->{$bucket}->{"HAVERES"} = 0;
		print "WARNING: no hospital_projections.txt result for " . $bucket . "\n";
	}
}

sub runOPProjections
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	my $bucketName = $args{bucketName};# || die "bucketName=> parameter is required\n";
	my $lstFile = $logDir . "/" . $bucketName . ".lst";
	my $logInp = $logDir . "/" . $bucketName . ".log";
	
	#run OP Projections
	system("sas -noterminal -memsize 4G " . $codeDir . "/project_OP.sas > /dev/null");
	system("cp project_OP.log " . $logInp) if(-e "project_OP.log");
	system("cp project_OP.lst " . $lstFile) if(-e "project_OP.lst");
	
	if(-e "overall_factor.txt")
	{
		open my $imfifh, "<", "overall_factor.txt";
		my $header = <$imfifh>;
		$header = MiscFunctions::cleanLine(line=>$header);
		my $imfofh;
		unless(-e "overall_factor_Final.txt")
		{
			open $imfofh, ">", "overall_factor_Final.txt";
			print $imfofh "BUCKET\t" . $header . "\n";
		}
		else
		{
			open $imfofh, ">>", "overall_factor_Final.txt";
		}
		while(my $line = <$imfifh>)
		{
			$line = MiscFunctions::cleanLine(line=>$line);
			print $imfofh $bucket . "\t" . $line . "\n";
		}
		close $imfifh;
		close $imfofh;
		system("rm " . "overall_factor.txt");
	}
	
	#collect OP stats from log/lst files
	collectOPStats(bucket=>$bucket);
	
	#save the bucket result if exists, else warn
	if(-e "hospital_projections.txt")
	{
		$memoryHash->{"BUCKET_STATS"}->{"OP"}->{$bucket}->{"HAVERES"} = 1;
		saveResult(inFile=>"hospital_projections.txt",saveFile=>"pxdxresult.txt",clearCol5=>"Y");
		saveResult(inFile=>"hospital_projections_nostar.txt",saveFile=>"pxdxresultnostar.txt",clearCol5=>"Y");
		print "done\n";
	}
	else
	{
		$memoryHash->{"BUCKET_STATS"}->{"OP"}->{$bucket}->{"HAVERES"} = 0;
		print "WARNING: no hospital_projections.txt result for " . $bucket . "\n";
	}
}

sub runFSProjections
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	my $bucketName = $args{bucketName};# || die "bucketName=> parameter is required\n";
	my $setting = $args{setting} || die "setting=> parameter is required\n";
	
	print "\n";
	print "\t\tOffice...";
	my $lstAsc = $logDir . "/" . $bucketName . "_asc.lst";
	my $logAsc = $logDir . "/" . $bucketName . "_asc.log";
	my $lstOff = $logDir . "/" . $bucketName . "_off.lst";
	my $logOff = $logDir . "/" . $bucketName . "_off.log";
	my $logLab = "../" . $logDir . "/" . $bucketName . "_lab.log";
	my $debLab = "../" . $logDir . "/" . $bucketName . "_debug.log";
	
	#run Office projections
	system("sas -noterminal -memsize 4G " . $codeDir . "/project_Office.sas");
	system("cp project_Office.log " . $logOff) if(-e "project_Office.log");
	system("cp project_Office.lst " . $lstOff) if(-e "project_Office.lst");
	
	#collect Office stats from log/lst files
	collectOfficeStats(bucket=>$bucket);
	
	#save the bucket result if exists, else warn
	#check bucket result if exists, else warn
	if(-e "office_projections.txt")
	{
		$memoryHash->{"BUCKET_STATS"}->{"OFFICE"}->{$bucket}->{"HAVERES"} = 1;
		
		open my $oifh, "<", "office_projections.txt";
		my $header = <$oifh>;
		while(my $line = <$oifh>)
		{
			$line = MiscFunctions::cleanLine(line=>$line);
			my @entry = split("\t",$line);
			my $piid = $entry[0];
			my $poid = $entry[1];
			my $tot = $entry[2];
			$memoryHash->{"OFFICE_POID_PIID_COUNTS"}->{$bucket}->{$poid}->{$piid} += $tot;
			$memoryHash->{"OFFICE_POID_COUNTS"}->{$bucket}->{$poid} += $tot;
		}
		close $oifh;
		open my $oofh, ">", "office_projections_wb.txt";
		print $oofh join("\t",qw/Bucket HMS_PIID HMS_POID PractFacClaimCount FacClaimCount/) . "\n";
		foreach my $y (keys %{$memoryHash->{"OFFICE_POID_PIID_COUNTS"}->{$bucket}})
		{
			foreach my $z (keys %{$memoryHash->{"OFFICE_POID_PIID_COUNTS"}->{$bucket}->{$y}})
			{
				my $poidPiidCnt = $memoryHash->{"OFFICE_POID_PIID_COUNTS"}->{$bucket}->{$y}->{$z};
				my $poidCnt = defined $memoryHash->{"OFFICE_POID_COUNTS"}->{$bucket}->{$y} ? $memoryHash->{"OFFICE_POID_COUNTS"}->{$bucket}->{$y} : "";
				my @outEntry = ();
				push(@outEntry,$bucket,$y,$z,$poidPiidCnt,$poidCnt);
				print $oofh join("\t",@outEntry) . "\n";
			}
		}
		close $oofh;
		delete $memoryHash->{"OFFICE_POID_PIID_COUNTS"};
		delete $memoryHash->{"OFFICE_POID_COUNTS"};
		saveResult(inFile=>"office_projections_wb.txt",saveFile=>"alloffice_nostar.txt");
		print "done\n";
	}
	else
	{
		$memoryHash->{"BUCKET_STATS"}->{"OFFICE"}->{$bucket}->{"HAVERES"} = 0;
		print "WARNING: no office_projections.txt result for " . $bucket . "\n";
	}
	
	#run ASC projections
	print "\t\tASC...";
	system("sas -noterminal -memsize 4G " . $codeDir . "/project_ASC.sas");
	system("cp project_ASC.log " . $logAsc) if(-e "project_ASC.log");
	system("cp project_ASC.lst " . $lstAsc) if(-e "project_ASC.lst");
	#collect stats from log and lst files for ASC
	collectASCStats(bucket=>$bucket);
	
	#check bucket result if exists, else warn
	if(-e "asc_projections.txt")
	{
		$memoryHash->{"BUCKET_STATS"}->{"ASC"}->{$bucket}->{"HAVERES"} = 1;
		
		open my $aifh, "<", "asc_projections.txt";
		open my $aofh, ">", "asc_projections_wb.txt";
		my $header = <$aifh>;
		$header = MiscFunctions::cleanLine(line=>$header);
		print $aofh join("\t",$bucket,$header) . "\n";
		while(my $line = <$aifh>)
		{
			$line = MiscFunctions::cleanLine(line=>$line);
			print $aofh join("\t",$bucket,$line) . "\n";
		}
		close $aifh;
		close $aofh;
		saveResult(inFile=>"asc_projections_wb.txt",saveFile=>"allasc_nostar.txt");
		print "done\n";
	}
	else
	{
		$memoryHash->{"BUCKET_STATS"}->{"ASC"}->{$bucket}->{"HAVERES"} = 0;
		print "WARNING: no asc_projections.txt result for " . $bucket . "\n";
	}
	
	my $pxdxResultFile = ($client eq "AB") ? "pxdxresult_nostar.txt" : "pxdxresultnostar.txt";
	
	#run LAB projections for Freestanding
	if($setting eq "Freestanding")
	{
		print "\t\tLAB...";
		system("mkdir","-p","Lab");
		chdir("Lab");
		
		#run lab projections
		system("project_lab.py > /dev/null");
		system("cp lab_proj.log $logLab") if (-e "lab_proj.log");
		system("cp lab_proj_debug.log $debLab") if (-e "lab_proj_debug.log");
		system("rm lab_proj.log.1") if (-e "lab_proj.log.1");
		system("rm lab_proj_debug.log.1") if (-e "lab_proj_debug.log.1");
		#collect stats from log files for lab
		collectLabStats(bucket=>$bucket);
		
		system("mv * ../");
		chdir("..");
		system("rm -rf Lab");
		#check bucket result if exists, else warn
		if(-e "lab_projection.txt")
		{
			$memoryHash->{"BUCKET_STATS"}->{"LAB"}->{$bucket}->{"HAVERES"} = 1;
			
			open my $lifh, "<", "lab_projection.txt";
			open my $lofh, ">", "lab_projections_wb.txt";
			my $header = <$lifh>;
			$header = MiscFunctions::cleanLine(line=>$header);
			print $lofh join("\t",$bucket,$header) . "\n";
			while(my $line = <$lifh>)
			{
				$line = MiscFunctions::cleanLine(line=>$line);
				print $lofh join("\t",$bucket,$line) . "\n";
			}
			close $lifh;
			close $lofh;
			saveResult(inFile=>"lab_projections_wb.txt",saveFile=>"alllab_nostar.txt");
			print "done\n";
		}
		else
		{
			$memoryHash->{"BUCKET_STATS"}->{"LAB"}->{$bucket}->{"HAVERES"} = 0;
			print "WARNING: no lab_projections.txt result for " . $bucket . "\n";
		}
		
		#combine step for office, asc, and lab
		system("combine_abcpm.py " . $bucket . " > /dev/null");
		
		if(-e "freestanding_projections.txt")
		{
			$memoryHash->{"BUCKET_STATS"}->{"FREESTANDING"}->{$bucket}->{"HAVERES"} = 1;
			saveResult(inFile=>"freestanding_projections.txt",saveFile=>"pxdxresult.txt");
			saveResult(inFile=>"freestanding_projections_nostar.txt",saveFile=>$pxdxResultFile);
			print "\tdone\n";
		}
		else
		{
			$memoryHash->{"BUCKET_STATS"}->{"FREESTANDING"}->{$bucket}->{"HAVERES"} = 0;
			print "WARNING: no freestanding_projections.txt result for " . $bucket . "\n";
		}
	}
	else
	{
		#combine step for office and asc
		system("sas -noterminal -memsize 4G " . $codeDir . "/combine_office_asc.sas");
		
		#save combined office + ASC bucket result if exists, else warn
		if(-e "office_asc_projections.txt")
		{
			$memoryHash->{"BUCKET_STATS"}->{"OFFICEASC"}->{$bucket}->{"HAVERES"} = 1;
			saveResult(inFile=>"office_asc_projections.txt",saveFile=>"pxdxresult.txt");
			saveResult(inFile=>"office_asc_projections_nostar.txt",saveFile=>$pxdxResultFile);
			print "\tdone\n";
		}
		else
		{
			$memoryHash->{"BUCKET_STATS"}->{"OFFICEASC"}->{$bucket}->{"HAVERES"} = 0;
			print "\tWARNING: no office_asc_projections.txt result for " . $bucket . "\n";
		}
	}
}

sub runSNFProjections
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	my $bucketName = $args{bucketName};# || die "bucketName=> parameter is required\n";
	my $starHandle = $args{starHandle} || die "starHandle=> parameter is required\n";
	my $noStarHandle = $args{noStarHandle} || die "noStarHandle=> parameter is required\n";
	my $stderrFile = $logDir . "/" . $bucketName . "_pacProjStdErr";
	
	open my $iofh, ">>", "input.txt";
	print $iofh "PACSettings\tSNF\n";
	close $iofh;
	
	#run SNF projections
	system("perl " . $codeDir . "/project_PAC.pl");
	system("cp pacProjStdErr " . $stderrFile);
	
	#save the bucket result if exists, else warn
	if(-e "pac_projections.txt")
	{
		#read the pac_projections.txt file, and build up the
		#pxdxresult.txt and pxdxresultnostar.txt - pay attention to
		#switching order of piid and poid columns
		$memoryHash->{"BUCKET_STATS"}->{"SNF"}->{$bucket}->{"HAVERES"} = 1;
		open my $pifh, "<", "pac_projections.txt";
		my ($header,$headerHash) = MiscFunctions::getHeadersFromHandle(ifh=>$pifh);
		while(my $line = <$pifh>)
		{
			$line = MiscFunctions::cleanLine(line=>$line);
			my @entry = split("\t",$line);
			my $piid = $entry[$headerHash->{"HMS_PIID"}];
			my $poid = $entry[$headerHash->{"HMS_POID"}];
			my $pfpNoStar = $entry[$headerHash->{"PRACTFACPROJCOUNT"}];
			my $fpNoStar = $entry[$headerHash->{"FACPROJCOUNT"}];
			my $pfpCnt = $pfpNoStar < 11 ? 5.5 : $pfpNoStar;
			my $fpCnt = $fpNoStar < 11 ? 5.5 : $fpNoStar;
			my @outEntry = ($bucket,$piid,$poid,$pfpCnt,$fpCnt);
			my @outEntryNoStar = ($bucket,$piid,$poid,$pfpNoStar,$fpNoStar);
			print $starHandle join("\t",@outEntry) . "\n";
			print $noStarHandle join("\t",@outEntryNoStar) . "\n";
		}
		close $pifh;
		print "done\n";
	}
	else
	{
		$memoryHash->{"BUCKET_STATS"}->{"SNF"}->{$bucket}->{"HAVERES"} = 0;
		print "WARNING: no pac_projections.txt result for " . $bucket . "\n";
	}
}

sub collectIPStats
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	
	my $statBucket;
	#collect some stats
	if(-e "project_IP_facility.lst")
	{
		my $nobs = `grep -w "Number of Observations Used" project_IP_facility.lst | egrep -v "Training|Testing" | tail -1`;
		chomp($nobs);
		my @nobsArr = split(" ",$nobs);
		$statBucket->{"NOBS"} = $nobsArr[-1];
	}
	else
	{
		$statBucket->{"NOBS"} = "";
	}
	
	if(-e "project_IP_facility.log")
	{
		my $highPf = `grep highpf: project_IP_facility.log | tail -1`;
		chomp($highPf);
		if(length($highPf) > 0)
		{
			my @highPfArr = split(" ",$highPf);
			$statBucket->{"HIGHPF"} = $highPfArr[-1] ne "\." ? $highPfArr[-1] : "";
		}
		else
		{
			$statBucket->{"HIGHPF"} = "";
		}
		
		my $lowPf = `grep lowpf: project_IP_facility.log | tail -1`;
		chomp($lowPf);
		if(length($lowPf) > 0)
		{
			my @lowPfArr = split(" ",$lowPf);
			$statBucket->{"LOWPF"} = $lowPfArr[-1] ne "\." ? $lowPfArr[-1] : "";
		}
		else
		{
			$statBucket->{"LOWPF"} = "";
		}
	}
	else
	{
		$statBucket->{"HIGHPF"} = "";
		$statBucket->{"LOWPF"} = "";
	}
	
	if(-e "project_IP_Practitioner.log")
	{
		my $medPf = `grep median project_IP_Practitioner.log | grep -v pf | tail -1`;
		chomp($medPf);
		if(length($medPf) > 0)
		{
			my @medPfArr = split(" ",$medPf);
			$statBucket->{"MEDPF"} = $medPfArr[-1] ne "\." ? $medPfArr[-1] : "";
		}
		else
		{
			$statBucket->{"MEDPF"} = "";
		}
		
		my $allPcl = `grep Total project_IP_Practitioner.log | grep claims | grep allpayer | tail -1`;
		chomp($allPcl);
		if(length($allPcl) > 0)
		{
			my @allPclArr = split(" ",$allPcl);
			$statBucket->{"ALLPCL"} = $allPclArr[-1];
		}
		else
		{
			$statBucket->{"ALLPCL"} = "";
		}
		
		my $cmsCl=`grep Total project_IP_Practitioner.log | grep claims | grep cms`;
		chomp($cmsCl);
		if(length($cmsCl) > 0)
		{
			my @cmsClArr = split(" ",$cmsCl);
			$statBucket->{"CMSCL"} = $cmsClArr[-1];
		}
		else
		{
			$statBucket->{"CMSCL"} = "";
		}
	}
	else
	{
		$statBucket->{"MEDPF"} = "";
		$statBucket->{"ALLPCL"} = "";
		$statBucket->{"CMSCL"} = "";
	}
	$memoryHash->{"BUCKET_STATS"}->{"IP"}->{$bucket} = $statBucket;
}

sub collectOPStats
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	
	my $statBucket;
	#collect some stats
	if(-e "project_OP.log")
	{
		my $highPf = `grep "max estimated factor" project_OP.log | egrep "^\*" | tail -1`;
		chomp($highPf);
		if(length($highPf) > 0)
		{
			my @highPfArr = split(" ",$highPf);
			$statBucket->{"HIGHPF"} = $highPfArr[-1] !~ m/(^\%|^\&)/ ? $highPfArr[-1] : "";
		}
		else
		{
			$statBucket->{"HIGHPF"} = "";
		}
		
		my $medPf = `grep "median estimated factor" project_OP.log | egrep "^\*" | tail -1`;
		chomp($medPf);
		if(length($medPf) > 0)
		{
			my @medPfArr = split(" ",$medPf);
			$statBucket->{"MEDPF"} = $medPfArr[-1] !~ m/(^\%|^\&)/ ? $medPfArr[-1] : "";
		}
		else
		{
			$statBucket->{"MEDPF"} = "";
		}
		
		my $lowPf = `grep "min estimated factor" project_OP.log | egrep "^\*" | tail -1`;
		chomp($lowPf);
		if(length($lowPf) > 0)
		{
			my @lowPfArr = split(" ",$lowPf);
			$statBucket->{"LOWPF"} = $lowPfArr[-1] !~ m/(^\%|^\&)/ ? $lowPfArr[-1] : "";
		}
		else
		{
			$statBucket->{"LOWPF"} = "";
		}
		
		my $totPoids = `grep number project_OP.log | grep observations | grep Total | tail -1`;
		chomp($totPoids);
		if(length($totPoids)> 0)
		{
			my @totPoidArr = split(" ",$totPoids);
			$statBucket->{"TOTPOIDS"} = $totPoidArr[-1] !~ m/(^\%|^\&)/ ? $totPoidArr[-1] : "";
		}
		else
		{
			$statBucket->{"TOTPOIDS"} = "";
		}
		
		my $allPcl = `grep Total project_OP.log | grep counts | grep allpayer | tail -1`;
		chomp($allPcl);
		if(length($allPcl) > 0)
		{
			my @allPclArr = split(" ",$allPcl);
			$statBucket->{"ALLPCL"} = $allPclArr[-1] !~ m/(^\%|^\&)/ ? $allPclArr[-1] : "";
		}
		else
		{
			$statBucket->{"ALLPCL"} = "";
		}
		
		my $cmsCl = `grep Total project_OP.log | grep counts | grep cms | tail -1`;
		chomp($cmsCl);
		if(length($cmsCl) > 0)
		{
			my @cmsClArr = split(" ",$cmsCl);
			$statBucket->{"CMSCL"} = $cmsClArr[-1] !~ m/(^\%|^\&)/ ? $cmsClArr[-1] : "";
		}
		else
		{
			$statBucket->{"CMSCL"} = "";
		}
	}
	
	if(-e "project_OP.lst")
	{
		my $nobs = `grep -w "Number of Observations Used" project_OP.lst`;
		chomp($nobs);
		my @nobsArr = split(" ",$nobs);
		$statBucket->{"NOBS"} = $nobsArr[-1];
	}
	else
	{
		$statBucket->{"NOBS"} = "";
	}
	$memoryHash->{"BUCKET_STATS"}->{"OP"}->{$bucket} = $statBucket;
}

sub collectOfficeStats
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	my $statBucket;
	
	my $medPf = -e "project_Office.log" ? `egrep "^Median" project_Office.log` : "";
	chomp($medPf);
	if(length($medPf) > 0)
	{
		my @medPfArr = split(" ",$medPf);
		$statBucket->{"MEDPF"} = $medPfArr[-1];
	}
	else
	{
		$statBucket->{"MEDPF"} = "";
	}
	
	my $nobs = -e "project_Office.lst" ? `grep -w "Number of Observations Used" project_Office.lst | tail -1` : "";
	chomp($nobs);
	if(length($nobs) > 0)
	{
		my @nobsArr = split(" ",$nobs);
		$statBucket->{"NOBS"} = $nobsArr[-1];
	}
	else
	{
		$statBucket->{"NOBS"} = "";
	}
	$memoryHash->{"BUCKET_STATS"}->{"OFFICE"}->{$bucket} = $statBucket;
}

sub collectASCStats
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	my $statBucket;
	
	my $medPf = -e "project_ASC.log" ? `egrep "^Median_pf_phys" project_ASC.log | tail -1` : "";
	chomp($medPf);
	if(length($medPf) > 0)
	{
		my @medPfArr = split("=",$medPf);
		my $medPfVal = $medPfArr[-1];
		$medPfVal = MiscFunctions::cleanLine(line=>$medPfVal,front=>"Y");
		$statBucket->{"MEDPF"} = $medPfVal;
	}
	else
	{
		$statBucket->{"MEDPF"} = "";
	}
	
	my $nobs = -e "project_ASC.lst" ? `grep -w "Number of Observations Used" project_ASC.lst | tail -1` : "";
	chomp($nobs);
	if(length($nobs) > 0)
	{
		my @nobsArr = split(" ",$nobs);
		$statBucket->{"NOBS"} = $nobsArr[-1];
	}
	else
	{
		$statBucket->{"NOBS"} = "";
	}
	$memoryHash->{"BUCKET_STATS"}->{"ASC"}->{$bucket} = $statBucket;
}

sub collectLabStats
{
	my %args = @_;
	my $bucket = $args{bucket};# || die "bucket=> parameter is required\n";
	
	my $recPulled = `grep "Pulled" lab_proj.log`;
	my @recs = split("\n",$recPulled);
	my $nobs = 0;
	foreach my $x (@recs)
	{
		$x =~ s/(^.*\|Pulled | records$)//g;
		$nobs += $x;
	}
	$memoryHash->{"BUCKET_STATS"}->{"LAB"}->{$bucket}->{"NOBS"} = $nobs;
}

sub saveResult
{
	my %args = @_;
	my $inFile = $args{inFile} || die "inFile=> parameter is required\n";
	my $saveFile = $args{saveFile} || die "saveFile=> parameter is required\n";
	my $clearCol5 = $args{clearCol5} || "";
	
	if(-e $saveFile)
	{
		unless($clearCol5 eq "")
		{
			system("tail -n +2 " . $inFile . " | cut -f1-4,6- >> " . $saveFile);
		}
		else
		{
			system("tail -n +2 " . $inFile . " >> " . $saveFile);
		}
	}
	else
	{
		unless($clearCol5 eq "")
		{
			system("cut -f1-4,6- " . $inFile . " > " . $saveFile);
		}
		else
		{
			system("cp " . $inFile . " " . $saveFile);
		}
	}
}

sub cleanMig
{
	#sub purpose: deal with problem of these types of migrations:
	# a->b
	# b->c
	# replace with a single record a->c
	
	my %args = @_;
	my $migUniq = $args{migUniq} || die "migUniq=> parameter is required\n";
	
	#read dirty migrations and store directed edges
	open my $mifh, "<", $migUniq;
	my $migHash;
	my ($header,$headerHash) = MiscFunctions::getHeadersFromHandle(ifh=>$mifh);
	while(my $line = <$mifh>)
	{
		$line = MiscFunctions::cleanLine(line=>$line);
		my @entry = split("\t",$line);
		my $old = $entry[$headerHash->{"OLD_VALUE"}];
		my $new = $entry[$headerHash->{"NEW_VALUE"}];
		#print $old . "-" . $new . "\n";
		unless($old eq $new) #ignore a->a
		{
			$migHash->{"FROM"}->{$old}->{$new}++;
			$migHash->{"TO"}->{$new}->{$old}++;
		}
	}
	
	#get rid of easy cycles
	#a->b
	#b->a
	#assume no dups in from
	#MiscFunctions::screenPrintHash(hash=>$migHash);
	foreach my $x (keys %{$migHash->{"FROM"}})
	{
		print $x . "\n";
		if(defined $migHash->{"FROM"}->{$x}) #check in case entry was deleted in a previous loop
		{
			my @fromArr = keys %{$migHash->{"FROM"}->{$x}};
			#print join("\t",@fromArr) . "\n";
			my $dest = scalar(keys %{$migHash->{"FROM"}->{$x}}) > 0 ? (keys %{$migHash->{"FROM"}->{$x}})[0] : "";
			#print $x . " dest: " . $dest . "\n";
			if($dest eq "")
			{
				foreach my $y (keys %{$migHash->{"FROM"}->{$dest}})
				{
					if($y eq $x)
					{
						delete $migHash->{"FROM"}->{$x}->{$dest};
						delete $migHash->{"TO"}->{$dest}->{$x};
						delete $migHash->{"FROM"}->{$dest}->{$y};
						delete $migHash->{"TO"}->{$y}->{$dest};
					}
				}
			}
		}
	}
	
	foreach my $x (keys %{$migHash->{"FROM"}})
	{
		if(scalar keys %{$migHash->{"FROM"}->{$x}} == 0)
		{
			delete $migHash->{"FROM"}->{$x};
		}
	}
	
	#MiscFunctions::screenPrintHash(hash=>$migHash->{"FROM"});
	#exit 0;
	
	open my $cofh, ">", "cleaned_migrations.tab";
	print $cofh "Old_Value\tNew_Value\n";
	#output the clean ones first
	#assume only one outward edge due to prior cleanup
	foreach my $x (keys %{$migHash->{"FROM"}})
	{
		#print $x . "\n";
		#find the destination node 
		my $dest = (keys %{$migHash->{"FROM"}->{$x}})[0];
		#print "dest: " . $dest . "\n";
		#make sure destination is not a from as well
		#and make sure the from is not a to as well
		#print "from hash with dest key: " . $migHash->{"FROM"}->{$dest} . "\n";
		#print "to hash with from key: " . $migHash->{"TO"}->{$x} . "\n";
		if((!defined $migHash->{"FROM"}->{$dest}) && (!defined $migHash->{"TO"}->{$x}))
		{
			#print "clean\n";
			#this edge is clean, output and delete it from the hashes
			print $cofh join("\t",$x,$dest) . "\n";
			delete $migHash->{"FROM"}->{$x};
			delete $migHash->{"TO"}->{$dest};
		}
		else
		{
			#print "not clean\n";
		} 
	}
	
	#DEBUG
	foreach my $x (keys %{$migHash->{"FROM"}})
	{
		my $dest = (keys %{$migHash->{"FROM"}->{$x}})[0];
		print join("\t",$x,$dest) . "\n";
	}
	
	#now loop through all remaining source nodes that are not also destinations
	#assumes from node wont go to multiple to nodes due to prior cleanup
	foreach my $x (keys %{$migHash->{"FROM"}})
	{
		#print "testing from = |$f|\n";
		unless(defined $migHash->{"TO"}->{$x})
		{
			#print $x . " is not a to\n";
			my $terminalTracker = 0;
			my $fromTracker = $x;
			my $dest;
			while($terminalTracker == 0)
			{
				$dest = (keys %{$migHash->{"FROM"}->{$fromTracker}})[0];
				#print "dest: " . $dest . "\n";
				if(defined $migHash->{"FROM"}->{$dest})
				{
					#print $dest . " is a from, keep going\n";
					delete $migHash->{"FROM"}->{$fromTracker};
					$fromTracker = $dest;
				}
				else
				{
					#print "reached the terminal\n";
					$terminalTracker = 1;
					delete $migHash->{"FROM"}->{$fromTracker};
				}
			}
			#print "cleaned\t" . $x . "\t" . $dest . "\n";
		}
	}
}

sub combMig
{
	#first read the poidvolcomp.txt to find out which old poids dropped
	open my $pifh, "<", "poidvolcomp.txt" or die "can't open poidvolcomp.txt\n";
	my ($header,$headerHash) = MiscFunctions::getHeadersFromHandle(ifh=>$pifh);
	my $dropHash;
	while(my $line = <$pifh>)
	{
		$line = MiscFunctions::cleanLine(line=>$line);
		my @entry = split("\t",$line);
		my $poid = $entry[$headerHash->{"HMS_POID"}];
		my $currTot = $entry[$headerHash->{"CURRTOTAL"}];
		my $prevTot = $entry[$headerHash->{"PREVTOTAL"}];
		$dropHash->{$poid}++ if $prevTot > 0.5 && $currTot < 0.5;
	}
	close $pifh;
	
	my $migHash;
	open my $cifh, "<", "cleaned_migrations.tab";
	($header,$headerHash) = MiscFunctions::getHeadersFromHandle(ifh=>$cifh);
	while(my $line = <$cifh>)
	{
		$line = MiscFunctions::cleanLine(line=>$line);
		my @entry = split("\t",$line);
		my $old = $entry[$headerHash->{"OLD_VALUE"}];
		my $new = $entry[$headerHash->{"NEW_VALUE"}];
		#only use rows where old poid dropped out of deliverable
		$migHash->{$old} = $new if(defined $dropHash->{$old});
	}
	close $cifh;
	
	open my $nifh, "<", "namebased_migrations.txt";
	($header,$headerHash) = MiscFunctions::getHeadersFromHandle(ifh=>$nifh);
	while(my $line = <$nifh>)
	{
		$line = MiscFunctions::cleanLine(line=>$line);
		my @entry = split("\t",$line);
		my $prevPoid = $entry[$headerHash->{"PREV_POID"}];
		my $currPoid = $entry[$headerHash->{"CURR_POID"}];
		#$migr{$f[0]}=$f[1] unless(defined $migr{$f[0]});
		$migHash->{$prevPoid} = $currPoid;
	}
	close $nifh;
	
	open my $fofh, ">", "final_migrations.txt";
	print $fofh "Old_Value\tNew_Value\n";
	foreach my $x (keys %{$migHash})
	{
		print $fofh join("\t",$x,$migHash->{$x}) . "\n";
	}
	close $fofh;
}



















































