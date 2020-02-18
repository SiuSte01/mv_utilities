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
		my $sitePath = `python -m site | grep $lib | grep site-packages`;
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
# and either run multiBucket_ABCPM.pl or QC scripts

#usage:
#perl run_ABCPM.pl  
#run from this months project directory

#before kicking off run_ABCPM.pl, need to do following steps:
#1)create config directory, copy settings.cfg from prior month config dir
#
#2)change vintage and job id (aggr id) in settings.cfg to whatever should 
#  be used this month
#3) copy over last month file runinputs.txt and make appropriate changes

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

#set the location of the QC R script
my $qcscript = $scatterDir . "/ABCPM_monthlyQC.R";

#open runinputs and grab the info
my %params;
open(INP,"runinputs.txt") or die "cant open runinputs.txt\n";
my @paramArr = ();
while(<INP>)
{
	chomp;
	s/\015//g;
	next if(m/^#/);
	next if(m/^$/);
	my @f=split '\t';
	$params{$f[0]}=$f[1];
	push(@paramArr,$f[0]);
}
close(INP);

#validate inputs
if(! defined $params{Client})
{
	print "must specify Client value\n";
	exit;
}
elsif(defined $params{Client})
{
	if($params{Client} ne "AB" && $params{Client} ne "CPM")
	{
		print "Client must be either AB or CPM\n";
		exit;
	}
}

if(! defined $params{AnalysisType})
{
	print "must specify AnalysisType value\n";
	exit;
}
elsif(defined $params{AnalysisType})
{
	if($params{AnalysisType} ne "Projections" && $params{AnalysisType} ne "QC" && $params{AnalysisType} ne "Buildmigrations" && $params{AnalysisType} ne "Checkmigrations")
	{
		print "AnalysisType must be either Projections or QC or Buildmigrations or Checkmigrations\n";
		exit;
	}
}

if(! defined $params{PrevDir})
{
	print "must specify PrevDir value\n";
	exit;
}
elsif(defined $params{PrevDir})
{
	if($params{PrevDir} eq "")
	{
		print "PrevDir must be specified\n";
		exit;
	} 
}

#make sure Prev and CurrMF locations are specified if AnalysisType is
#  Buildmigrations
if($params{AnalysisType} eq "Buildmigrations")
{
	if(! defined $params{PrevMF})
	{
		print "Must specify PrevMF for Buildmigrations option\n";
		exit;
	}
	elsif(defined $params{PrevMF})
	{
		if($params{PrevMF} eq "")
		{
			print "Must specify PrevMF value for Buildmigrations option\n";
		}
	}
	
	if(! defined $params{CurrMF})
	{
		print "Must specify CurrMF for Buildmigrations option\n";
		exit;
	}
	elsif(defined $params{CurrMF})
	{
		if($params{CurrMF} eq "")
		{
			print "Must specify CurrMF value for Buildmigrations option\n";
		}
	}
}

#set the location of the migrations-related scripts
my $migdir = $codeDir . "/AdvisoryBoard";


#define the setting names hash based on input
#assume that it is one or more of the current 5 AB or CPM settings
my %settings;
if(! defined $params{Settings})
{
	print "must specify comma separated settings\n";
	exit;
}
$settings{IP}++ if($params{Settings} =~ m/IP/);
$settings{OP}++ if($params{Settings} =~ m/OP/);
$settings{Freestanding}++ if($params{Settings} =~ m/Freestanding/);
$settings{OfficeASC}++ if($params{Settings} =~ m/OfficeASC/);
$settings{SNF}++ if($params{Settings} =~ m/SNF/);


#read config/settings.cfg and get the vintage and db login info
my ($vint,$username,$password,$instance);
open(INP2,"config/settings.cfg") or die "cant open config/settings.cfg\n";
while(<INP2>)
{
	chomp;
	s/\015//g;
	next if(m/^#/);
	if(m/VINTAGE/)
	{
		my @f=split ' = ';
		my @g=split('\/',$f[1]);
		$vint="$g[2]$g[0]$g[1]";
	}
	if(m/USERNAME/)
	{
		my @f=split ' = ';
		$username=$f[1];
	}
	if(m/PASSWORD/)
	{
		my @f=split ' = ';
		$password=$f[1];
	}
	if(m/INSTANCE/)
	{
		my @f=split ' = ';
		$instance=$f[1];
	}
}
close(INP2);

if($params{AnalysisType} eq "Projections")
{	
	#create input.txt file which was initially generated by createxwalks.pl
	my $memoryHash;
	my $hgRoot = "/vol/cs/clientprojects/mv_utilities/projCode";
	$memoryHash->{"SET_VARS"} = MiscFunctions::createSettingHash(config=>"config/settings.cfg");
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"SET_VARS"});
	if($memoryHash->{"SET_VARS"}->{"FXFILES"}[0] ne "NULL" && $memoryHash->{"SET_VARS"}->{"FXFILES"}[0] =~ m/\//)
	{
		die "FXFILES has a '/' character. FXFILES cannot be a path and must be a suffix or null. run_ABCPM quitting\n";
	}
	if(lc($memoryHash->{"SET_VARS"}->{"FXFILES"}[0]) eq "master")
	{
		die "FXFILES cannot be set to master\n";
	}
	my $vintage = $memoryHash->{"SET_VARS"}->{"VINTAGE"}[0];
	$vintage = MiscFunctions::normalizeDate(date=>$vintage,yyyymmdd=>"Y");
	my $fxFiles = $hgRoot . "/";
	if($memoryHash->{"SET_VARS"}->{"FXFILES"}[0] eq "NULL")
	{
		$fxFiles .= "InputDataFiles/" . $envName;
	}
	else
	{
		$fxFiles .= "InputDataFiles/" . $memoryHash->{"SET_VARS"}->{"FXFILES"}[0];
	}
	my $instance = $memoryHash->{"SET_VARS"}->{"INSTANCE"}[0];
	my $username = $memoryHash->{"SET_VARS"}->{"USERNAME"}[0];
	my $password = $memoryHash->{"SET_VARS"}->{"PASSWORD"}[0];
	my $jobId = $memoryHash->{"SET_VARS"}->{"JOB_ID"}[0];
	open my $iofh, ">", "input.txt";
	print $iofh "Parameter\tValue\n";
	print $iofh "VINTAGE\t" . $vintage . "\n";
	print $iofh "FXFILES\t" . $fxFiles . "\n";
	print $iofh "INSTANCE\t" . $instance . "\n";
	print $iofh "USERNAME\t" . $username . "\n";
	print $iofh "PASSWORD\t" . $password . "\n";
	print $iofh "AGGREGATION_ID\t" . $jobId . "\n";
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
	my $cxwStatus = system("createxwalks.py");
	die "createxwalks finished with non-zero exit code: " . $cxwStatus . ". run_ABCPM quitting.\n" unless $cxwStatus == 0;
	
	#next, loop over settings:
	SETTLOOP: foreach my $sett (sort keys %settings)
	{
		#EM edited 10.4.17 - will include Freestanding for AB as of 10.15 delivery
		#next SETTLOOP if($params{Client} eq "AB" && $sett eq "Freestanding");
		# create the setting directories if don't exist
		system("mkdir","-p",$sett);
		
		# copy over buckets.txt and donotproject.txt
		my $prevbucketf=$params{PrevDir} . "/" . $sett . "/buckets.txt";
		system("cp " . $prevbucketf . " " . $sett);
		
		my $prevdonotprojf=$params{PrevDir} . "/" . $sett . "/donotproject.txt";
		system("cp " . $prevdonotprojf . " " . $sett) if(-e $prevdonotprojf);
		
		# cd into each setting; run multiBucket_ABCPM.pl and send email; and cd back up
		chdir($sett);
		print "RUNNING multiBucket_ABCPM for setting: " . $sett . "\n";
		my $mbTimeBegin = time();
		system("perl " . $codeDir . "/multiBucket_ABCPM.pl $params{Client} $sett");
		#my $emailstr=$sett." Projections";
		#system("perl " . $codeDir . "/sendemail.pl $emailstr");
		my $mbTimeEnd = time();
		print "multiBucket_ABCPM for setting: " . $sett . " complete\n";
		my $mbRunTime = $mbTimeEnd - $mbTimeBegin;
		my $mbMinutes = $mbRunTime/60;
		print "Job took " . $mbMinutes . " minutes\n";
		chdir("..");
	}
}
elsif($params{AnalysisType} eq "QC")
{
	#create the proj-level input file
	#create the compinput.txt file
	open(OUT,">compinput.txt") or die "cant create compinput.txt\n";
	print OUT "Parameter\tValue\n";
	print OUT "PrevDir\t$params{PrevDir}\n";
	print OUT "Vintage\t$vint\n";
	print OUT "DBInstance\t$instance\n";
	print OUT "DBUsername\t$username\n";
	print OUT "DBPassword\t$password\n";
	close(OUT);
	
	#go into each setting and run the QC R script if setting and result exists
	foreach my $sett (sort keys %settings)
	{
		if(-e $sett)
		{
			chdir($sett);
			if(-e "pxdxresult.txt")
			{
				print "RUNNING QC for setting: " . $sett . "\n";
				my $qcTimeBegin = time();
				system("R CMD BATCH --vanilla $qcscript");
				#my $emailstr=$sett." QC script";
				#system("perl " . $codeDir . "/sendemail.pl $emailstr");
				my $qcTimeEnd = time();
				print "QC for setting: " . $sett . " complete\n";
				my $qcRunTime = $qcTimeEnd - $qcTimeBegin;
				my $qcMinutes = $qcRunTime/60;
				print "Job took " . $qcMinutes . " minutes\n";
			}
			else
			{
				print "cant find pxdxresult.txt for |$sett|, skipping QC for this setting\n";
			}
			chdir("..");
		}
	}
}
elsif($params{AnalysisType} eq "Buildmigrations")
{
	#create the compinput.txt file needed for migrations
	open(OUT,">compinput.txt") or die "cant create compinput.txt\n";
	print OUT "Parameter\tValue\n";
	print OUT "PrevMF\t$params{PrevMF}\n";
	print OUT "CurrMF\t$params{CurrMF}\n";
	close(OUT);
	
	#CHANGE 20181207 - create cleaned_migrations.tab file (which will now sit in project directory) from CurrMF migrations 
	#Create the name of the dirty migrations file from the CurrMF and call perl code to clean migrations
	my @g=split("\/",$params{CurrMF});
	my $fileloc=join("\/",@g[0 .. ($#g-2)]);
	my $dirtymig = $fileloc."/migration_unique.tab";
	system("perl " . $codeDir . "/AdvisoryBoard/clean_migrations.pl $dirtymig");
	my $clmigfile="cleaned_migrations.tab";
	
	#go into each setting and run the build migr steps if setting and result exists
	foreach my $sett (sort keys %settings)
	{
		if(-e $sett)
		{
			chdir($sett);
			if(-e "poidvolcomp.txt")
			{
				print "RUNNING Buildmigrations for setting: " . $sett . "\n";
				my $bmTimeBegin = time();
				system("ln -s ../$clmigfile .");
				system("R CMD BATCH --vanilla $migdir/buildmigrations_v2.R");
				my $bmTimeEnd = time();
				print "Buildmigrations for setting: " . $sett . " complete\n";
				my $bmRunTime = $bmTimeEnd - $bmTimeBegin;
				my $bmMinutes = $bmRunTime/60;
				print "Job took " . $bmMinutes . " minutes\n";
				#my $emailstr=$sett." buildmigrations steps";
				#system("perl " . $codeDir . "/sendemail.pl $emailstr");
			}
			else
			{
				print "cant find poidvolcomp.txt file for |$sett|, skipping Buildmigations for this setting\n";
			}
			chdir("..");
		}
	}
}
elsif($params{AnalysisType} eq "Checkmigrations")
{
	#create the compinput.txt file needed for migrations
	open(OUT,">compinput.txt") or die "cant create compinput.txt\n";
	print OUT "Parameter\tValue\n";
	print OUT "PrevMF\t$params{PrevMF}\n";
	print OUT "CurrMF\t$params{CurrMF}\n";
	close(OUT);
	
	#go into each setting and run the build migr steps if setting and result exists
	foreach my $sett (sort keys %settings)
	{
		if(-e $sett)
		{
			chdir($sett);
			if(-e "namebased_migrations.txt")
			{
				print "RUNNING Checkmigrations for setting: " . $sett . "\n";
				my $cmTimeBegin = time();
				system("perl $migdir/combinemigrations.pl");
				system("R CMD BATCH --vanilla $migdir/checkmigr.R");
				system("R CMD BATCH --vanilla $migdir/createmigratedpoidgraph.R");
				my $cmTimeEnd = time();
				print "Checkmigrations for setting: " . $sett . " complete\n";
				my $cmRunTime = $cmTimeEnd - $cmTimeBegin;
				my $cmMinutes = $cmRunTime/60;
				print "Job took " . $cmMinutes . " minutes\n";
				#my $emailstr=$sett." checkmigrations steps";
				#system("perl " . $codeDir . "/sendemail.pl $emailstr");
			}
			else
			{
				print "cant find namebased_migrations.txt for |$sett|, skipping Checkmigrations for this setting\n";
			}
			chdir("..");
		}
	}
}

my $subject = "run_ABCPM Job: \"" . $params{AnalysisType} . "\" complete";
my $message = "Your run_ABCPM Job is finished running.\n" .
	"\tClient: " . $params{Client} . "\n" .
	"\tAnalysisType: " . $params{AnalysisType} . "\n" .
	"\tRun Location: " . `pwd` . "\n";
MiscFunctions::sendEmail(subject=>$subject,message=>$message);

system("chmod 777 -R --silent .");
