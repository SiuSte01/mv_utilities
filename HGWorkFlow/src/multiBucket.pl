#!/usr/bin/env perl

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
BEGIN
{
	$envName = "perl_utilities";
	$scriptDir = Cwd::abs_path(dirname($0));
	my $lib = dirname($scriptDir);
	if($lib =~ m/mv_utilities/)
	{
		$codeDir = $lib . "/src";
		$lib =~ s/mv_utilities.*/perl_utilities/;
		$libDir = Cwd::abs_path($lib) . "/lib";
		$aggrDir = Cwd::abs_path($lib) . "/aggr";
	}
	else
	{
		$lib = `conda info -e | grep '*'`;
		$envName = $lib;
		$envName =~ s/\*.*//;
		$envName =~ s/^\s+|\s+$//g;
		$lib =~ s/^.*\*//;
		$lib =~ s/^\s+|\s+$//g;
		my $sitePath = `python -m site | grep $lib | grep site-packages`;
		$sitePath =~ s/^\s+|\s+$//g;
		$sitePath =~ s/('|,)//g;
		$libDir = $sitePath . "/lib";
		$aggrDir = $sitePath . "/aggr";
		$codeDir = $sitePath . "/HGWorkFlow/src";
	}
}
use lib $libDir;
use MiscFunctions;

my @ogArgs = @ARGV;
if(-e "debug")
{
	print "ARGV for " . $0 . ":\n";
	print Dumper(@ogArgs);
}

my $timeBegin = time();

my $config;
my $break;

GetOptions(
	"config=s"	=>\$config,
	"break"		=>\$break
);

die "-config parameter is required\n" unless $config;

#MiscFunctions::setEnv();
#system("which createxwalks.py");

my $settingVars = MiscFunctions::createSettingHash(config=>$config);
my $jvsTab = "config/jobVendorSettings.tab";
my $cgrTab = "config/codeGroupRules.tab";
my $cgmTab = "config/codeGroupMembers.tab";

my $rootLoc = getcwd();
my $codeRepo = "/vol/cs/clientprojects/mv_utilities/HGWorkFlow";
my $projections = "Projections";
my $codes = "codes";
my $runComb = 0;
my $combMak = "/vol/cs/clientprojects/PxDxStandardizationTesting/scripts/DB_PLDWH2DBR/Combine_RY/Makefile";

my @jvsHeader = qw/BUCKET SETTINGS PRACTITIONER_ROLES COUNT_TYPE/;
my @jvsKey = qw/BUCKET/;
my @cgrHeader = qw/BUCKET_NAME BUCKET_TYPE CODE_GROUP1 CODE_GROUP2 CODE_GROUP1_ID CODE_GROUP2_ID/;
my @cgrKey = qw/BUCKET_NAME/;
my @cgmHeader = qw/CODE_GROUP_NAME CODE CODE_GROUP_TYPE/;
my @cgmKey = qw/CODE_GROUP_NAME CODE/;

my $memoryHash;
my $validCMS;

$validCMS->{"ip"} = "ip";
$validCMS->{"op"} = "op";
$validCMS->{"office"} = "office";
$validCMS->{"asc"} = "asc";
$validCMS->{"lab"} = "lab";
$validCMS->{"home"} = "home";
$validCMS->{"hha"} = "hha";
$validCMS->{"hospice"} = "hospice";
$validCMS->{"snf"} = "snf";

readInputs();
my $settingsUsed;
my @settingsUsedArr = ();
foreach my $x (keys %{$memoryHash->{"JVS_RAW"}})
{
	my $settings = $memoryHash->{"JVS_RAW"}->{$x}->{"SETTINGS"};
	my @settingsArr = split(",",$settings);
	foreach my $y (@settingsArr)
	{
		$settingsUsed->{lc($y)} = 1;
	}
}
foreach my $x (keys %{$settingsUsed})
{
	push(@settingsUsedArr,$x);
}
my @settingsUsedArrSorted = sort {lc($a) cmp lc($b)} @settingsUsedArr;

#MiscFunctions::screenPrintHash(hash=>$memoryHash,keysOnly=>"Y");
my $requestType = "P";
$requestType = $settingVars->{"REQUEST_TYPE"}[0] if(exists $settingVars->{"REQUEST_TYPE"} && $settingVars->{"REQUEST_TYPE"}[0] ne "NULL");

my @buckets = ();
foreach my $x (keys %{$memoryHash->{"JVS_RAW"}})
{
	push(@buckets,$x);
}
my @bucketsSorted = sort {lc($a) cmp lc($b)} @buckets;

if($requestType eq "P")
{
	executeProjectedProcess();
}
elsif($requestType eq "U")
{
	executeUnprojectedProcess();
}
elsif($requestType eq "B")
{
	executeBothProcesses();
}

system("chmod 777 -R --silent .");

my $timeEnd = time();

my $runTime = $timeEnd - $timeBegin;
print "\nProcess Complete: " . $0 . "\n";
my $minutes = $runTime/60;
print "Job took " . $minutes ." minutes\n";

#End of main code

sub executeProjectedProcess
{
	if(uc($settingVars->{"ANALYSIS_TYPE"}[0]) eq "PROJECTIONS")
	{
		runProjectionsStep();
		unless($break)
		{
			runMakefileStep(requestType=>"projected");
			runQCStep();
		}
	}
	elsif(uc($settingVars->{"ANALYSIS_TYPE"}[0]) eq "MAKEFILE")
	{
		runMakefileStep(requestType=>"projected");
		unless($break)
		{
			runQCStep();
		}
	}
	elsif(uc($settingVars->{"ANALYSIS_TYPE"}[0]) eq "QC")
	{
		runQCStep();
	}
	else
	{
		die $settingVars->{"ANALYSIS_TYPE"}[0] . ": Option \"ANALYSIS_TYPE\" must have one of the following values: \"Projections\", \"Makefile\" or \"QC\"\n";
	}
}

sub executeUnprojectedProcess
{
	runMakefileStep(requestType=>"unprojected");
}

sub executeBothProcesses
{
	executeUnprojectedProcess();
	executeProjectedProcess();
	print "Both Processes Finished\n";
}

sub runProjectionsStep
{
	my $fxFiles = $codeRepo . "/";
	$fxFiles .= $settingVars->{"FXFILES"}[0] ne "NULL" ? "InputDataFiles_NewWH_" . $settingVars->{"FXFILES"}[0] : "InputDataFiles_NewWH";
	system("mkdir","-p",$fxFiles);
	my @reqFiles = qw/ahd_beds_nodup.sas7bdat aha_demo.sas7bdat covar_under65.sas7bdat covar_county_unemp.sas7bdat covar_ma_penetration.sas7bdat covar_hi_expend.sas7bdat CMS_ASC_ProcedureData.txt HospitalExclusionList.tab ins_mapenet.sas7bdat mdsi_bedcount_audit.sas7bdat test_u65byhsa.sas7bdat xwalk_zip.sas7bdat zip2fips.sas7bdat/;
	print $fxFiles . "\n";
	foreach my $x (@reqFiles)
	{
		unless(-e $fxFiles . "/" . $x)
		{
			system("cp " . $codeRepo . "/InputDataFiles_NewWH/" . $x . " " . $fxFiles . "/" . $x);
		}
	}
	my $cxwStatus = system("createxwalks.py");
	die "createxwalks finished with non-zero exit code: " . $cxwStatus . ". multiBucket quitting.\n" unless $cxwStatus == 0;
	buildFolders();
	runProjections();
}

sub runMakefileStep
{
	my %args = @_;
	my $requestType = $args{requestType} || die "requestType=> parameter is required\n";
	my @targs = ("buckets");
	#"patch buckets combined counts";
	unless(uc($settingVars->{"DONT_PATCH"}[0]) eq "Y")
	{
		push(@targs,"patch");
	}
	if(uc($settingVars->{"COMBINE_BUCKETS"}[0]) eq "Y")
	{
		push(@targs,"combined","counts");
	}
	#print "targs: " . join("-",@targs) . "\n";
	#exit 0;
	print "RUNNING PXDX_REPORT...\n";
	my $pxdxCmd = "";
	if(-e "bucketsToBuild.tab")
	{
		my @b2bKey = qw/BUCKET/;
		$memoryHash->{"BUCKETS_TO_BUILD"} = MiscFunctions::fillDataHashes(file=>"bucketsToBuild.tab",hashKey=>\@b2bKey);
		#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"BUCKETS_TO_BUILD"},sample=>3);
		my @b2b = ();
		foreach my $x (keys %{$memoryHash->{"BUCKETS_TO_BUILD"}})
		{
			push(@b2b,$x);
		}
		$pxdxCmd = "pxdx_report . --targets " . join(" ",@targs) . " --include-buckets " . join(" ", @b2b) . " --debug --request " . $requestType;
		delete $memoryHash->{"BUCKETS_TO_BUILD"};
	}
	else
	{
		$pxdxCmd = "pxdx_report . --targets " . join(" ",@targs) . " --debug --request " . $requestType;
	}
	#print $pxdxCmd . "\n";
	#exit 0;
	system($pxdxCmd);
	print "RUNNING PXDX_REPORT done\n";
}

sub runQCStep
{
	foreach my $x (@bucketsSorted)
	{
		my $bucket = $memoryHash->{"JVS_RAW"}->{$x}->{"BUCKET"};
		my $bucketType = $memoryHash->{"CGR_RAW"}->{$x}->{"BUCKET_TYPE"};
		my $codeGroup1 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP1"};
		my $codeGroup2 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP2"};
		my $codeGroup3 = "";
		$codeGroup3 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP3"};
#		my $codeTypes = keys %{$memoryHash->{"CODES_DATA"}->{$x}};
#		die $x . " does not have only one code type!\n" unless $codeTypes eq 1;
		my $type = "";
		if($bucketType eq "SINGLE")
		{
			$type = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODE_GROUP_TYPE"};
		}
		elsif($bucketType eq "COOCCUR")
		{
			$type = "cooccur";
		}
		elsif($bucketType eq "UNION")
		{
			$type = "union";
		}
		else
		{
			die "Bad bucket type: " . $bucketType . "\n";
		}
		print "RUNNING QC CHECK FOR " . $bucket . "...";
		die "\n\tQA Directory missing for bucket " . $bucket . "\n" unless -d $bucket . "/QA";
		chdir($bucket . "/QA");
		system("R CMD BATCH --vanilla /vol/datadev/Statistics/Katie/New_Script_KE/QA_full_tab_new_KE_v3.R");
		print "done\n";
		chdir($rootLoc);
	}
	system("wc -l */Projections/*/*_projection* > projection_counts.txt");
	if(uc($settingVars->{"COMBINE_BUCKETS"}[0]) eq "Y")
	{
		print "RUNNING QC CHECK FOR Combined Deliverable...";
		die "\n\tmilestones Directory missing for Combined Deliverable\n" unless -d "milestones";
		chdir("milestones");
		system("R CMD BATCH --vanilla /vol/datadev/Statistics/Katie/New_Script_KE/QA_full_tab_new_KE_v3.R");
		print "done\n";
		chdir($rootLoc);
	}
}

sub readInputs
{
	if($settingVars->{"FXFILES"}[0] ne "NULL" && $settingVars->{"FXFILES"}[0] =~ m/\//)
	{
		die "FXFILES has a '/' character. FXFILES cannot be a path and must be a suffix or null. multiBucket quitting\n";
	}
	if(lc($envName) eq "master" && $settingVars->{"FXFILES"}[0] ne "NULL")
	{
		die "FXFILES must be null when running multiBucket in the " . $envName . " environment\n";
	}
	elsif(lc($envName) ne "master" && $settingVars->{"FXFILES"}[0] eq "NULL")
	{
		die "FXFILES cannot be null when running multiBucket in the " . $envName . " environment\n";
	}
	$memoryHash->{"JVS_RAW"} = MiscFunctions::fillDataHashes(file=>$jvsTab,hashKey=>\@jvsKey);
	$memoryHash->{"CGR_RAW"} = MiscFunctions::fillDataHashes(file=>$cgrTab,hashKey=>\@cgrKey);
	$memoryHash->{"CGM_RAW"} = MiscFunctions::fillDataHashes(file=>$cgmTab,hashKey=>\@cgmKey);
	if(-e "donotproject.tab")
	{
		my @dnpKey = qw/BUCKET/;
		$memoryHash->{"DNP_BUCKETS"} = MiscFunctions::fillDataHashes(file=>"donotproject.tab",hashKey=>\@dnpKey);
		foreach my $x (keys %{$memoryHash->{"DNP_BUCKETS"}})
		{
			unless(defined $memoryHash->{"DNP_BUCKETS"}->{$x}->{"SETTINGS"})
			{
				$memoryHash->{"DNP_BUCKETS"}->{$x}->{"SETTINGS"}->{"ip"} = 1;
				$memoryHash->{"DNP_BUCKETS"}->{$x}->{"SETTINGS"}->{"op"} = 1;
			}
			else
			{
				my @setArr = split(",",$memoryHash->{"DNP_BUCKETS"}->{$x}->{"SETTINGS"});
				delete $memoryHash->{"DNP_BUCKETS"}->{$x}->{"SETTINGS"};
				foreach my $y (@setArr)
				{
					$memoryHash->{"DNP_BUCKETS"}->{$x}->{"SETTINGS"}->{lc($y)} = 1;
				}
			}
		}
		#print Dumper($memoryHash->{"DNP_BUCKETS"});
		#exit 0;
	}
	
	foreach my $x (keys %{$memoryHash->{"CGM_RAW"}})
	{
		my $codeGroupName = $memoryHash->{"CGM_RAW"}->{$x}->{"CODE_GROUP_NAME"};
		my $codeGroupType = $memoryHash->{"CGM_RAW"}->{$x}->{"CODE_GROUP_TYPE"};
		my $code = $memoryHash->{"CGM_RAW"}->{$x}->{"CODE"};
		my $scheme = $memoryHash->{"CGM_RAW"}->{$x}->{"CODE_SCHEME"};
		$memoryHash->{"CODES_DATA_RAW"}->{$codeGroupName}->{"CODES"}->{$code}->{"CODE_VALUE"} = $code;
		$memoryHash->{"CODES_DATA_RAW"}->{$codeGroupName}->{"CODES"}->{$code}->{"CODE_SCHEME"} = $scheme;
		$memoryHash->{"CODES_DATA_RAW"}->{$codeGroupName}->{"CODE_GROUP_TYPE"} = $codeGroupType;
	}
	foreach my $x (keys %{$memoryHash->{"JVS_RAW"}})
	{
		my $bucket = $memoryHash->{"JVS_RAW"}->{$x}->{"BUCKET"};
		my $bucketType = $memoryHash->{"CGR_RAW"}->{$x}->{"BUCKET_TYPE"};
		my $codeGroup1 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP1"};
		my $codeGroup2 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP2"};
		my $codeGroup3 = "";
		$codeGroup3 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP3"} if exists $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP3"};
		my $type = "";
		if($bucketType eq "SINGLE")
		{
			#$bucket = $codeGroup1;
			$type = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODE_GROUP_TYPE"};
			my $scheme = "";
			foreach my $y (keys %{$memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODES"}})
			{
				$scheme = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODES"}->{$y}->{"CODE_SCHEME"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE"} = $y;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"TYPE"} = $type;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"} = $scheme;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"FROM"} = $codeGroup1;
			}
		}
		elsif($bucketType eq "COOCCUR")
		{
			$type = "cooccur";
			my $scheme = "";
			foreach my $y (keys %{$memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODES"}})
			{
				$scheme = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODES"}->{$y}->{"CODE_SCHEME"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE"} = $y;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"TYPE"} = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODE_GROUP_TYPE"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"} = $scheme;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"FROM"} = $codeGroup1;
			}
			foreach my $y (keys %{$memoryHash->{"CODES_DATA_RAW"}->{$codeGroup2}->{"CODES"}})
			{
				$scheme = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup2}->{"CODES"}->{$y}->{"CODE_SCHEME"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE"} = $y;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"TYPE"} = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup2}->{"CODE_GROUP_TYPE"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"} = $scheme;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"FROM"} = $codeGroup2;
			}
			if($codeGroup3 ne "")
			{
				foreach my $y (keys %{$memoryHash->{"CODES_DATA_RAW"}->{$codeGroup3}->{"CODES"}})
				{
					$scheme = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup3}->{"CODES"}->{$y}->{"CODE_SCHEME"};
					$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE"} = $y;
					$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"TYPE"} = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup3}->{"CODE_GROUP_TYPE"};
					$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"} = $scheme;
					$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"FROM"} = $codeGroup3;
				}
			}
		}
		elsif($bucketType eq "UNION")
		{
			$type = "union";
			my $scheme = "";
			foreach my $y (keys %{$memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODES"}})
			{
				$scheme = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODES"}->{$y}->{"CODE_SCHEME"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE"} = $y;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"TYPE"} = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODE_GROUP_TYPE"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"} = $scheme;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"FROM"} = $codeGroup1;
			}
			foreach my $y (keys %{$memoryHash->{"CODES_DATA_RAW"}->{$codeGroup2}->{"CODES"}})
			{
				$scheme = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODES"}->{$y}->{"CODE_SCHEME"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE"} = $y;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"TYPE"} = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup2}->{"CODE_GROUP_TYPE"};
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"} = $scheme;
				$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"FROM"} = $codeGroup2;
			}
			if($codeGroup3 ne "")
			{
				foreach my $y (keys %{$memoryHash->{"CODES_DATA_RAW"}->{$codeGroup3}->{"CODES"}})
				{
					$scheme = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup3}->{"CODES"}->{$y}->{"CODE_SCHEME"};
					$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE"} = $y;
					$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"TYPE"} = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup3}->{"CODE_GROUP_TYPE"};
					$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"} = $scheme;
					$memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"FROM"} = $codeGroup3;
				}
			}
		}
		else
		{
			die "Bad bucket type: " . $bucketType . "\n";
		}
	}
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"JVS_RAW"});
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"CGR_RAW"});
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"CGM_RAW"});
	#MiscFunctions::screenPrintHash(hash=>$memoryHash,keysOnly=>"Y");
}

sub buildFolders
{
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"JVS_RAW"});
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"CGR_RAW"});
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"CGM_RAW"});
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"CODES_DATA"});
	#MiscFunctions::screenPrintHash(hash=>$memoryHash,keysOnly=>"Y");
	#For each unique bucket in the bucket file, build folder structure, create project settings folders
	foreach my $x (@bucketsSorted)
	{
		my $bucket = $memoryHash->{"JVS_RAW"}->{$x}->{"BUCKET"};
		my $bucketType = $memoryHash->{"CGR_RAW"}->{$x}->{"BUCKET_TYPE"};
		my $codeGroup1 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP1"};
		my $codeGroup2 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP2"};
		my $codeGroup3 = "";
		$codeGroup3 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP3"} if exists $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP3"};
#		my $codeTypes = keys %{$memoryHash->{"CODES_DATA"}->{$x}};
#		die $x . " does not have only one code type!\n" unless $codeTypes eq 1;
		my $type = "";
		if($bucketType eq "SINGLE")
		{
			# $bucket = $codeGroup1;
			$type = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODE_GROUP_TYPE"};
		}
		elsif($bucketType eq "COOCCUR")
		{
			$type = "cooccur";
		}
		elsif($bucketType eq "UNION")
		{
			$type = "union";
		}
		else
		{
			die "Bad bucket type: " . $bucketType . "\n";
		}
		print "BUILDING FOLDER STRUCTURE FOR " . $bucket . "\n";
		print "\ttype: " . $type . "\n";
		
		#Create Codes Folder
		system("mkdir","-p",$bucket . "/" . $codes);
		open my $cfh, ">", $bucket . "/" . $codes . "/codesTemp.tab";
		foreach my $y (keys %{$memoryHash->{"CODES_DATA"}->{$bucket}})
		{
			my $code = $y;
			my $scheme = $memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"};
			$code =~ s/\.//g;
			print $cfh $code . "\t" . $scheme . "\n";
		}
		close $cfh;
		
		system("sort -k2,2 -k1,1 " . $bucket . "/" . $codes . "/codesTemp.tab > " . $bucket . "/" . $codes . "/codes.tab");
		system("rm " . $bucket . "/" . $codes . "/codesTemp.tab");
		
		#Create Projections Folder
		system("mkdir","-p",$bucket . "/" . $projections);
		my $hospRoot = $bucket . "/" . $projections . "/Hospital";
		my @hospFilesToClear = ("hospital_projections.txt","hospclaims.txt","patcnts.txt","doccnts_WKUB.txt","doccnts_CMS.txt","hospcnts_WKUB.txt","doccnts_CMS.txt","medianhospratio.txt","IP/hospital_projections.txt","IP/hospital_projections_nostar.txt","OP/hospital_projections.txt","OP/hospital_projections_nostar.txt");
		foreach my $x (@hospFilesToClear)
		{
			if(-e $hospRoot . "/" . $x)
			{
				#print "removing " . $x . "\n";
				system("rm " . $hospRoot . "/" . $x);
			}
		}
		if(-e "pract_filter.txt")
		{
			system("cp pract_filter.txt " . $bucket . "/pract_filter.txt");
		}
		if(-e "spec_filter.txt")
		{
			system("cp spec_filter.txt " . $bucket . "/spec_filter.txt");
		}
		if(-e "zip_codes.txt")
		{
			system("cp zip_codes.txt " . $bucket . "/zip_codes.txt");
		}
		
		my @setting = split(",",$memoryHash->{"JVS_RAW"}->{$x}->{"SETTINGS"});
		foreach my $y (@setting)
		{
			$y = MiscFunctions::cleanLine(line=>$y,front=>"y",back=>"y");
			die "BUCKET: " . $bucket . "\tInvalid CMS Setting: " . $y . "\n" unless exists $validCMS->{$y};
		}
		my $count = $memoryHash->{"JVS_RAW"}->{$x}->{"COUNT_TYPE"};
		die "BUCKET: " . $bucket . "\tInvalid Count type: " . $count . "\n" unless(($count eq "PATIENT") or ($count eq "CLAIM") or ($count eq "PROC"));

		##########COMMENT BLOCK FOR input.txt##########
		#Adding project settings to bucket specific settings.mak. Creating Projectons folders for various settings
		my $options = MiscFunctions::convertToHash(array=>\@setting);
		my $inputFile = "input.txt";
		unless(-e $bucket . "/" . $projections . "/" . $inputFile)
		{
			open my $ofh, ">", $bucket . "/" . $projections . "/" . $inputFile;
			printInputFile(handle=>$ofh,bucket=>$bucket,count=>$count,type=>$type,options=>$options);
			close $ofh;
		}
		##########END COMMENT BLOCK FOR input.txt##########
		
		my $vint = $settingVars->{"VINTAGE"}[0];
		my @dateArr = split("/",$vint);
		my $vintageDate = $dateArr[2] . $dateArr[0] . $dateArr[1];
		#system("cp cms_poidlist.sas7bdat " . $bucket . "/Projections/Hospital/IP/cms_poidlist.sas7bdat");
		#system("cp wk_poidlist.sas7bdat " . $bucket . "/Projections/Hospital/IP/wk_poidlist.sas7bdat");
		
		if(exists $options->{"ip"} or $options->{"op"})
		{
			system("mkdir","-p",$bucket . "/" . $projections . "/Hospital");
			MiscFunctions::symlinkFile(file=>$bucket . "/" . $projections . "/" . $inputFile,path=>$bucket . "/" . $projections . "/Hospital");
			if(exists $options->{"ip"})
			{
				system("mkdir","-p",$bucket . "/" . $projections . "/Hospital/IP");
				if($type eq "ALL")
				{
					foreach my $x ("Child","NonChild")
					{
						system("mkdir","-p",$bucket . "/" . $projections . "/Hospital/IP/" . $x);
						system("cp -r " . $bucket . "/" . $projections . "/" . $inputFile . " " . $bucket . "/" . $projections . "/Hospital/IP/" . $x);
						open my $aiifh,">>", $bucket . "/" . $projections . "/Hospital/IP/" . $x . "/" . $inputFile;
						if($x eq "Child")
						{
							MiscFunctions::symlinkFile(file=>"ip_matrix_child.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x,outFile=>"ip_matrix.sas7bdat");
							MiscFunctions::symlinkFile(file=>"poid_volume_child.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x,outFile=>"poid_volume.sas7bdat");
							MiscFunctions::symlinkFile(file=>"poid_attributes_ip_child.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x,outFile=>"poid_attributes_ip.sas7bdat");
							print $aiifh "PROJECTIP\tN\n";
						}
						elsif($x eq "NonChild")
						{
							MiscFunctions::symlinkFile(file=>"ip_matrix_nonchild.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x,outFile=>"ip_matrix.sas7bdat");
							MiscFunctions::symlinkFile(file=>"poid_volume_nonchild.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x,outFile=>"poid_volume.sas7bdat");
							MiscFunctions::symlinkFile(file=>"poid_attributes_ip_nonchild.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x,outFile=>"poid_attributes_ip.sas7bdat");
						}
						MiscFunctions::symlinkFile(file=>"cms_poidlist.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x);
						MiscFunctions::symlinkFile(file=>"wk_poidlist.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x);
						MiscFunctions::symlinkFile(file=>"state_poidlist.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP/" . $x);
						close $aiifh;
					}
					system("cp -r " . $bucket . "/" . $projections . "/" . $inputFile . " " . $bucket . "/" . $projections . "/Hospital/IP");
					open my $aiifh,">>",$bucket . "/" . $projections . "/Hospital/IP/" . $inputFile;
					print $aiifh "Filter1500Specialty\tY\n";
					close $aiifh;
					MiscFunctions::symlinkFile(file=>"ip_datamatrix.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP");
				}
				else
				{
					MiscFunctions::symlinkFile(file=>$bucket . "/" . $projections . "/" . $inputFile,path=>$bucket . "/" . $projections . "/Hospital/IP");
					MiscFunctions::symlinkFile(file=>"cms_poidlist.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP");
					MiscFunctions::symlinkFile(file=>"ip_datamatrix.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP");
					MiscFunctions::symlinkFile(file=>"poid_volume.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP");
					MiscFunctions::symlinkFile(file=>"wk_poidlist.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP");
					MiscFunctions::symlinkFile(file=>"state_poidlist.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP");
					MiscFunctions::symlinkFile(file=>"poid_attributes_ip.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/IP");
				}
			}
			if(exists $options->{"op"})
			{
				system("mkdir","-p",$bucket . "/" . $projections . "/Hospital/OP");
				MiscFunctions::symlinkFile(file=>$bucket . "/" . $projections . "/" . $inputFile,path=>$bucket . "/" . $projections . "/Hospital/OP");
				MiscFunctions::symlinkFile(file=>"op_datamatrix.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/OP");
				MiscFunctions::symlinkFile(file=>"poid_attributes_op.sas7bdat",path=>$bucket . "/" . $projections . "/Hospital/OP");
			}
		}
		if(exists $options->{"hha"} or $options->{"hospice"} or $options->{"snf"})
		{
			system("mkdir","-p",$bucket . "/" . $projections . "/PAC");
			MiscFunctions::symlinkFile(file=>$bucket . "/" . $projections . "/" . $inputFile,path=>$bucket . "/" . $projections . "/PAC");
		}
		if(exists $options->{"home"})
		{
			system("mkdir","-p",$bucket . "/" . $projections . "/Home");
			MiscFunctions::symlinkFile(file=>$bucket . "/" . $projections . "/" . $inputFile,path=>$bucket . "/" . $projections . "/Home");
		}
		if(exists $options->{"office"})
		{
			system("mkdir","-p",$bucket . "/" . $projections . "/Office");
			MiscFunctions::symlinkFile(file=>$bucket . "/" . $projections . "/" . $inputFile,path=>$bucket . "/" . $projections . "/Office");
		}
		if(exists $options->{"lab"})
		{
			system("mkdir","-p",$bucket . "/" . $projections . "/Lab");
			MiscFunctions::symlinkFile(file=>$bucket . "/" . $projections . "/" . $inputFile,path=>$bucket . "/" . $projections . "/Lab");
		}
		if(exists $options->{"asc"})
		{
			system("mkdir","-p",$bucket . "/" . $projections . "/ASC");
			MiscFunctions::symlinkFile(file=>$bucket . "/" . $projections . "/" . $inputFile,path=>$bucket . "/" . $projections . "/ASC");
			MiscFunctions::symlinkFile(file=>"asc_datamatrix.sas7bdat",path=>$bucket . "/" . $projections . "/ASC");
		}
	}
}

sub printInputFile
{
	my %args = @_;
	my $handle = $args{handle} || die "\nhandle=> parameter is required\n";
	my $bucket = $args{bucket} || die "\nbucket=> parameter is required\n";
	my $count = $args{count} || die "\ncount=> parameter is required\n";
	my $type = $args{type} || die "\ntype=> parameter is required\n";
	my $options = $args{options} || die "\noptions=> parameter is required\n";
	my $vint = $settingVars->{"VINTAGE"}[0];
	my $aggrId = $settingVars->{"JOB_ID"}[0];
	my $user = $settingVars->{"USERNAME"}[0];
	my $pass = $settingVars->{"PASSWORD"}[0];
	my $inst = $settingVars->{"INSTANCE"}[0];
	my $aggrTab = $settingVars->{"AGGREGATION_TABLE"}[0];
	my $claimPatTable = $settingVars->{"CLAIM_PATIENT_TABLE"}[0];
	my $fxFiles = $codeRepo . "/";
	$fxFiles .= $settingVars->{"FXFILES"}[0] ne "NULL" ? "InputDataFiles_NewWH_" . $settingVars->{"FXFILES"}[0] : "InputDataFiles_NewWH";
	my $addRefOverride = uc($settingVars->{"ADD_REF_OVERRIDE"}[0]);
	my $addRefDocFlag = "N";
	if($addRefOverride eq "Y")
	{
		$addRefDocFlag = "Y";
	}
	my $hospitalType = "";
	
	$memoryHash->{$bucket}->{"PX_ICD910"} = 0;
	$memoryHash->{$bucket}->{"PX_CPT"} = 0;
	my $hasPx = 0;
	my $hasDx = 0;
	my $hasDrg = 0;
	my $hasAll = 0;
	
	#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"CODES_DATA"});
	#print $bucket . "\n";
	foreach my $x (keys %{$memoryHash->{"CODES_DATA"}->{$bucket}})
	{
		my $code = $x;
		my $codeType = lc($memoryHash->{"CODES_DATA"}->{$bucket}->{$x}->{"TYPE"});
		#print "-" . $codeType . "-\n";
		if($codeType eq "px")
		{
			$hasPx = 1;
		}
		elsif($codeType eq "dx")
		{
			$hasDx = 1;
		}
		elsif($codeType eq "drg")
		{
			$hasDrg = 1;
		}
		elsif($codeType eq "all")
		{
			$hasAll = 1;
		}
		else
		{
			print Dumper($memoryHash->{"CODES_DATA"}->{$bucket});
			die $codeType . " is a bad code type\n";
		}
		$code =~ s/\.//g;
		my $codeLen = length($code);
		if(($codeType eq "px") and ($codeLen eq 5))
		{
			$memoryHash->{$bucket}->{"PX_CPT"} = 1;
		}
		elsif($codeType eq "px")
		{
			$memoryHash->{$bucket}->{"PX_ICD910"} = 1;
		}
	}
	
	if((exists $options->{"ip"}) or (exists $options->{"op"}))
	{
		if($hasDx)
		{
			if((exists $options->{"ip"}) and (exists $options->{"op"}))
			{
				$hospitalType = "IPOP";
			}
			elsif(exists $options->{"ip"})
			{
				$hospitalType = "IP";
			}
			elsif(exists $options->{"op"})
			{
				$hospitalType = "OP";
			}
			else
			{
				print Dumper($options);
				die "Bad options\n";
			}
		}
		elsif($hasPx)
		{
			if($memoryHash->{$bucket}->{"PX_ICD910"} and $memoryHash->{$bucket}->{"PX_CPT"})
			{
				$hospitalType = "IPOP";
			}
			elsif($memoryHash->{$bucket}->{"PX_ICD910"})
			{
				$hospitalType = "IP";
			}
			elsif($memoryHash->{$bucket}->{"PX_CPT"})
			{
				$hospitalType = "OP";
			}
			else
			{
				die "Neither PX_ICD910 nor PX_CPT flags are 1 for bucket " . $bucket . "\n";
			}
		}
		elsif($hasDrg)
		{
			$hospitalType = "IP";
		}
		elsif($hasAll)
		{
			if((exists $options->{"ip"}) and (exists $options->{"op"}))
			{
				$hospitalType = "IPOP";
			}
			elsif(exists $options->{"ip"})
			{
				$hospitalType = "IP";
			}
			elsif(exists $options->{"op"})
			{
				$hospitalType = "OP";
			}
			else
			{
				print Dumper($options);
				die "Bad options\n";
			}
		}
	}
	
	foreach my $y (keys %{$memoryHash->{"CODES_DATA"}->{$bucket}})
	{
		if(($y =~ m/^(J|C|S)/) && (uc($memoryHash->{"CODES_DATA"}->{$bucket}->{$y}->{"CODE_SCHEME"}) eq "HCPCS"))
		{
			$addRefDocFlag = "Y";
		}
	}
	if($vint =~ m/\//)
	{
		my @vintArr = split("/",$vint);
		$vint = $vintArr[2] . $vintArr[0] . $vintArr[1];
	}
	
#	if($type eq "ALL")
#	{
#		$bucket = "ALL";
#	}
	
	print $handle "Parameter\tValue\n";
	print $handle "COUNTTYPE\t" . $count . "\n";
	print $handle "CODETYPE\t" . uc($type) . "\n";
	print $handle "VINTAGE\t" . $vint . "\n";
	if(uc($settingVars->{"UPCASE_BUCKETS"}[0]) eq "Y")
	{
		print $handle "BUCKET\t" . uc($bucket) . "\n";
	}
	else
	{
		print $handle "BUCKET\t" . $bucket . "\n";
	}
	print $handle "AGGREGATION_ID\t" . $aggrId . "\n";
	print $handle "USERNAME\t" . $user . "\n";
	print $handle "PASSWORD\t" . $pass . "\n";
	print $handle "INSTANCE\t" . $inst . "\n";
	print $handle "AGGREGATION_TABLE\t" . $aggrTab . "\n";
	print $handle "CLAIM_PATIENT_TABLE\t" . $claimPatTable . "\n";
	print $handle "FXFILES\t" . $fxFiles . "\n";
	print $handle "AddRefDoc\t" . $addRefDocFlag . "\n";
	unless ($hospitalType eq "")
	{
		print $handle "HospitalType\t" . $hospitalType . "\n";
	}
	foreach my $y (qw/ip op office asc/)
	{
		if(exists $options->{$y} && exists $memoryHash->{"DNP_BUCKETS"}->{$bucket}->{"SETTINGS"}->{$y})
		{
			my $set = $y;
			$set = "off" if $y eq "office";
			print $handle "PROJECT" . uc($set) . "\tN\n";
		}
	}
	if((exists $options->{"hha"}) or (exists $options->{"hospice"}) or (exists $options->{"snf"}))
	{
		my @pacArray = ();
		if(exists $options->{"hha"})
		{
			push(@pacArray,"HHA");
		}
		if(exists $options->{"hospice"})
		{
			push(@pacArray,"HOSPICE");
		}
		if(exists $options->{"snf"})
		{
			push(@pacArray,"SNF");
		}
		print $handle "PACSettings\t" . join(",",@pacArray) . "\n";
	}
}

sub runProjections
{
	foreach my $x (@bucketsSorted)
	{
		my $bucket = $memoryHash->{"JVS_RAW"}->{$x}->{"BUCKET"};
		my $bucketType = $memoryHash->{"CGR_RAW"}->{$x}->{"BUCKET_TYPE"};
		my $codeGroup1 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP1"};
		my $codeGroup2 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP2"};
		my $codeGroup3 = "";
		$codeGroup3 = $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP3"} if exists $memoryHash->{"CGR_RAW"}->{$x}->{"CODE_GROUP3"};
		my $type = "";
		if($bucketType eq "SINGLE")
		{
			$type = $memoryHash->{"CODES_DATA_RAW"}->{$codeGroup1}->{"CODE_GROUP_TYPE"};
		}
		elsif($bucketType eq "COOCCUR")
		{
			$type = "cooccur";
		}
		elsif($bucketType eq "UNION")
		{
			$type = "union";
		}
		else
		{
			die "Bad bucket type: " . $bucketType . "\n";
		}
		my @setting = split(",",$memoryHash->{"JVS_RAW"}->{$x}->{"SETTINGS"});
		foreach my $y (@setting)
		{
			$y = MiscFunctions::cleanLine(line=>$y,front=>"y",back=>"y");
		}
		
		print "\tRUNNING PROJECTIONS FOR " . $bucket . "\n";
		
		#Creating Projectons folders for various settings
		my $options = MiscFunctions::convertToHash(array=>\@setting);
		#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"Biopsy"});
		#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"Thyrotoxicosis"});
		#MiscFunctions::screenPrintHash(hash=>$memoryHash->{"Thyrotoxicosis_Biopsy"});
		#MiscFunctions::screenPrintHash(hash=>$memoryHash,keysOnly=>"Y");
		
		if(exists $options->{"office"})
		{
			if(($type eq "PX") and ($memoryHash->{$bucket}->{"PX_ICD910"}) and !($memoryHash->{$bucket}->{"PX_CPT"}))
			{
				print "\t\tSKIPPING RUNNING OFFICE PROJECTIONS FOR " . $bucket . "\n";
			}
			else
			{
				print "\t\tRUNNING OFFICE PROJECTIONS FOR " . $bucket . "\n";
				chdir($bucket . "/Projections/Office");
				#print "sas -noterminal -memsize 4G " . $codeDir . "/project_Office.sas\n";
				system("sas -noterminal -memsize 4G " . $codeDir . "/project_Office.sas");
				unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
				{
					system("rm *sas7*");
				}
				chdir($rootLoc);
			}
		}
		if(exists $options->{"asc"})
		{
			if(($type eq "PX") and ($memoryHash->{$x}->{"PX_ICD910"}) and !($memoryHash->{$x}->{"PX_CPT"}))
			{
				print "\t\tSKIPPING RUNNING ASC PROJECTIONS FOR " . $bucket . "\n";
			}
			else
			{
				print "\t\tRUNNING ASC Projections for " . $bucket . "\n";
				chdir($bucket . "/Projections/ASC");
				#print "sas -noterminal -memsize 4G " . $codeDir . "/project_ASC.sas\n";
				system("sas -noterminal -memsize 4G " . $codeDir . "/project_ASC.sas");
				chdir($rootLoc);
			}
		}
		
		if(exists $options->{"ip"})
		{
			if(($type eq "PX") and !($memoryHash->{$bucket}->{"PX_ICD910"}) and ($memoryHash->{$bucket}->{"PX_CPT"}))
			{
				print "\t\tSKIPPING RUNNING IP PROJECTIONS FOR " . $bucket . "\n";
			}
			elsif($type eq "ALL")
			{
				print "\t\tRUNNING IP PROJECTIONS FOR ALL BUCKET: " . $bucket . "\n";
				foreach my $x ("Child","NonChild")
				{
					chdir($bucket . "/Projections/Hospital/IP/" . $x);
					system("sas -noterminal -memsize 4G " . $codeDir . "/project_IP_facility.sas");
					if($x eq "NonChild")
					{
						MiscFunctions::symlinkFile(file=>"poidpf.sas7bdat",path=>"../");
						MiscFunctions::symlinkFile(file=>"pfmax.sas7bdat",path=>"../");
					}
					chdir($rootLoc);
				}
				chdir($bucket . "/Projections/Hospital/IP");
				system("sas -noterminal -memsize 4G " . $codeDir . "/project_IP_CombineFacility.sas");
				system("sas -noterminal -memsize 4G " . $codeDir . "/project_IP_Practitioner.sas");
				chdir($rootLoc);
			}
			else
			{
				print "\t\tRUNNING IP PROJECTIONS FOR " . $bucket . "\n";
				my $vint = $settingVars->{"VINTAGE"}[0];
				my @dateArr = split("/",$vint);
				my $vintageDate = $dateArr[2] . $dateArr[0] . $dateArr[1];
				chdir($bucket . "/Projections/Hospital/IP");
				system("sas -noterminal -memsize 4G " . $codeDir . "/project_IP_facility.sas");
				system("sas -noterminal -memsize 4G " . $codeDir . "/project_IP_Practitioner.sas");
				chdir($rootLoc);
			}
		}
		if(exists $options->{"op"})
		{
			if(($type eq "PX") and ($memoryHash->{$bucket}->{"PX_ICD910"}) and !($memoryHash->{$bucket}->{"PX_CPT"}))
			{
				print "\t\tSKIPPING RUNNING OP PROJECTIONS FOR " . $bucket . "\n";
			}
			else
			{
				print "\t\tRUNNING OP PROJECTIONS FOR " . $bucket . "\n";
				chdir($bucket . "/Projections/Hospital/OP");
				system("sas -noterminal -memsize 4G " . $codeDir . "/project_OP.sas");
				chdir($rootLoc);
			}
		}
		
		if(exists $options->{"ip"} and exists $options->{"op"})
		{
			chdir($bucket . "/Projections/Hospital");
			if(-e "IP/hospital_projections.txt" and -e "OP/hospital_projections.txt")
			{
				system("sas -noterminal " . $codeDir . "/combineipop.sas");
				unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
				{
					system("rm IP/*sas7*");
					system("rm OP/*sas7*");
					if(-e "IP/Child")
					{
						system("rm IP/Child/*sas7*");
					}
					if(-e "IP/NonChild")
					{
						system("rm IP/NonChild/*sas7*");
					}
				}
			}
			elsif(-e "IP/hospital_projections.txt")
			{
				print "WARNING - OP hospital projections does not exist. Using only IP\n";
				system("cut -f2- IP/hospital_projections_nostar.txt > hospital_projections.txt");
				unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
				{
					system("rm IP/*sas7*");
					if(-e "IP/Child")
					{
						system("rm IP/Child/*sas7*");
					}
					if(-e "IP/NonChild")
					{
						system("rm IP/NonChild/*sas7*");
					}
				}
			}
			elsif(-e "OP/hospital_projections.txt")
			{
				print "WARNING - IP hospital projections does not exist. Using only OP\n";
				system("cut -f2- OP/hospital_projections_nostar.txt > hospital_projections.txt");
				unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
				{
					system("rm OP/*sas7*");
				}
			}
			chdir($rootLoc);
		}
		else
		{
			if(exists $options->{"ip"})
			{
				chdir($bucket . "/Projections/Hospital");
				if(-e "IP/hospital_projections_nostar.txt")
				{
					system("cut -f2- IP/hospital_projections_nostar.txt > hospital_projections.txt");
				}
				unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
				{
					system("rm IP/*sas7*");
					if(-e "IP/Child")
					{
						system("rm IP/Child/*sas7*");
					}
					if(-e "IP/NonChild")
					{
						system("rm IP/NonChild/*sas7*");
					}
				}
				chdir($rootLoc);
			}
			elsif(exists $options->{"op"})
			{
				chdir($bucket . "/Projections/Hospital");
				if(-e "OP/hospital_projections_nostar.txt")
				{
					system("cut -f2- OP/hospital_projections_nostar.txt > hospital_projections.txt");
				}
				unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
				{
					system("rm OP/*sas7*");
				}
				chdir($rootLoc);
			}
		}
		my $count = $memoryHash->{"JVS_RAW"}->{$x}->{"COUNT_TYPE"};
		if($count eq "PATIENT")
		{
			if((exists $options->{"ip"}) or (exists $options->{"op"}))
			{
				chdir($bucket . "/Projections/Hospital");
				system("perl " . $codeDir . "/dopatients.pl");
				chdir($rootLoc);
			}
		}
		
		if(exists $options->{"lab"})
		{
			print "\t\tRUNNING LAB Projections for " . $bucket . "\n";
			chdir($bucket . "/Projections/Lab");
			system("project_lab.py --scale-missing");
			chdir($rootLoc);
		}
		
		if(exists $options->{"home"})
		{
			print "\t\tRUNNING HOME Projections for " . $bucket . "\n";
			chdir($bucket . "/Projections/Home");
			system("project_home.py");
			chdir($rootLoc);
		}
		
		if((exists $options->{"hha"}) or (exists $options->{"hospice"}) or (exists $options->{"snf"}))
		{
			print "\t\tRUNNING PAC Projections for " . $bucket . "\n";
			chdir($bucket . "/Projections/PAC");
			system("perl " . $codeDir . "/project_PAC.pl");
			chdir($rootLoc);
			if((-e $bucket . "/Projections/PAC/pac_projections.txt") && (-e $bucket . "/Projections/Hospital/hospital_projections.txt"))
			{
				system("mv " . $bucket . "/Projections/Hospital/hospital_projections.txt " . $bucket . "/Projections/Hospital/hospital_projections_nopac.txt");
				chdir($bucket . "/Projections/Hospital");
				system("sas -noterminal " . $codeDir . "/combinehospac.sas");
				chdir($rootLoc);
			}
			else
			{
				system("mkdir","-p",$bucket . "/Projections/Hospital");
				open my $ifh, "<", $bucket . "/Projections/PAC/pac_projections.txt";
				open my $ofh, ">", $bucket . "/Projections/Hospital/hospital_projections.txt";
				my $pacProjHeader = <$ifh>;
				$pacProjHeader = MiscFunctions::cleanLine(line=>$pacProjHeader);
				my @pacProjHeaderArr = split("\t",$pacProjHeader);
				print $ofh join("\t",$pacProjHeaderArr[1],$pacProjHeaderArr[0],$pacProjHeaderArr[2],$pacProjHeaderArr[3],$pacProjHeaderArr[4]) . "\n";
				while(my $line = <$ifh>)
				{
					$line = MiscFunctions::cleanLine(line=>$line);
					my @entry = split("\t",$line);
					print $ofh join("\t",$entry[1],$entry[0],$entry[2],$entry[3],$entry[4]) . "\n";
				}
				close $ifh;
				close $ofh;
			}
		}
	}
	unless(uc($settingVars->{"PRESERVE_SAS"}[0]) eq "Y")
	{
		system("rm *sas7*");
	}
}




































