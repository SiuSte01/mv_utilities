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
BEGIN
{
	$scriptDir = Cwd::abs_path(dirname($0));
	my $lib = dirname($scriptDir);
	if($lib =~ m/mv_utilities/)
	{
		$lib =~ s/mv_utilities.*/perl_utilities/;
		$libDir = Cwd::abs_path($lib) . "/lib";
		$aggrDir = Cwd::abs_path($lib) . "/aggr";
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
	}
}
use lib $libDir;
use MiscFunctions;

#usage perl /vol/datadev/Statistics/Projects/HGWorkFlow/Dev/multiBucket_ABCPM.pl AB|CPM IP|OP|Freestanding|OfficeASC|SNF  Dev|Prod_NewWH
#looks for a file called buckets.txt in current directory
#optionally can have donotproject.txt in current dir with list of buckets
# to not project for IP and OP at present

my $npar=scalar(@ARGV);
my ($jobtype,$setting,$codebase);
if($npar==3)
{
	$jobtype=$ARGV[0];
	$setting=$ARGV[1];
	$codebase=$ARGV[2];
}
else
{
	print "\tspecify exactly 3 parameters on command line\n";
	exit;
}

$ENV{CODEBASE}=uc $codebase;
my $codedir = "/vol/datadev/Statistics/Projects/HGWorkFlow/$codebase";

my $memoryHash;

#read the bucket list, assume bucket name in 1st column
open(INP,"buckets.txt") or die "cant open buckets.txt\n";
my %b2type; #type value is Proj or NoProj
while(<INP>)
{
	chomp;
	s/\015//g;
	if($. > 1)
	{
		my @f=split '\t';
		$f[0]=~s/^\s+//g;
		$f[0]=~s/\s+$//g;
		$b2type{$f[0]}="Proj";
	}
}
close(INP);

#read the do not project list if provided
if(-e "../donotproject.txt")
{
	my @dnpKey = qw/BUCKET/;
	$memoryHash->{"DNP_BUCKETS"} = MiscFunctions::fillDataHashes(file=>"../donotproject.txt",hashKey=>\@dnpKey);
	foreach my $x (keys %{$memoryHash->{"DNP_BUCKETS"}})
	{
		$b2type{$x}="NoProj";
	}
}

#grab the aggregation table name and vintage from settings.cfg
my ($aggr_table,$vint);
open(SETT,"../config/settings.cfg") or die "cant open ../config/settings.cfg\n";
while(<SETT>)
{
	chomp;
	s/\015//g;
	if(m/AGGREGATION_TABLE/)
	{
		my @f=split ' = ';
		$aggr_table=$f[1];
	}
	if(m/VINTAGE/)
	{
		my @f=split ' = ';
		my @g=split('\/',$f[1]);
		$vint="$g[2]$g[0]$g[1]";
	}
}
close(SETT);

system("rm -f pxdxresult.txt");
system("rm -f pxdxresultnostar.txt");
system("rm -f *.log") unless($setting eq "SNF");
system("rm -f *.lst") unless($setting eq "SNF");
my %bstats;

if($setting eq "SNF")
{
	#need to create the * and no * versions
	open(SNFST,">pxdxresult.txt");
	open(SNFNOST,">pxdxresultnostar.txt");
	print SNFST "Bucket\tHMS_PIID\tHMS_POID\tPractFacProjCount\t";
	print SNFST "FacProjCount\n";
	print SNFNOST "Bucket\tHMS_PIID\tHMS_POID\tPractFacProjCount\t";
	print SNFNOST "FacProjCount\n";
}

foreach my $b (keys %b2type)
{
	#print $b . "\t" . $b2type{$b} . "\n";
	#create bucket name without special chars and spaces
	my $b2=$b;
	$b2=~s/\s+//g;
	$b2=~s/\///g;
	$b2=~s/\(//g;
	$b2=~s/\)//g;
	$b2=~s/\///g;
	
	#do the things needed in all settings, then do the setting-specific stuff
	
	#first clean up from previous bucket
	system("rm -f hospital_projections.txt");
	system("rm -f hospital_projections_nostar.txt");
	system("rm -f *sas7bdat*") unless($setting eq "SNF");
	system("rm -f junk");
	system("rm -f input.txt");
	system("rm -f asc_projections.txt");
	system("rm -f asc_projections_wb.txt");
	system("rm -f office_projections.txt");
	system("rm -f office_projections_wb.txt");
	
	#create input file by copying from 1 level up, and then appending
	# bucket-specific stuff
	system("cp ../input.txt .");
	open(OUT,">>input.txt");
	print OUT "AGGREGATION_TABLE\t$aggr_table\n";
	print OUT "BUCKET\t$b\n";
	print OUT "COUNTTYPE\tCLAIM\n";
	print OUT "CODETYPE\t$jobtype\n";
	print OUT "AddRefDoc\tN\n";
	print OUT "Filter1500Specialty\tN\n";
	close(OUT);
	
	if($setting eq "IP")
	{
		if(defined $memoryHash->{"DNP_BUCKETS"}->{$b})
		{
			open(OUT,">>input.txt");
			print OUT "PROJECTIP\tN\n";
			close(OUT);
		}
		
		#save the lst and log
		my $lst="lst_$b2";
		my $loginp="log_input_$b2";
		my $logfac="log_fac_$b2";
		
		#now symlink files needed from project directory
		system("ln -s ../cms_poidlist.sas7bdat .");
		system("ln -s ../ip_datamatrix.sas7bdat .");
		system("ln -s ../poid_volume.sas7bdat .");
		system("ln -s ../state_poidlist.sas7bdat .");
		system("ln -s ../wk_poidlist.sas7bdat .");
		system("ln -s ../poid_attributes_ip.sas7bdat .");
		
#		if($b2type{$b} eq "Proj" || $b2type{$b} eq "NoProj")
#		{
		system("sas -noterminal -memsize 4G $codedir/project_IP_facility.sas > junk");
		system("sas -noterminal -memsize 4G $codedir/project_IP_Practitioner.sas");
		system("cp project_IP_facility.lst $lst") if(-e "project_IP_facility.lst");
		system("cp project_IP_facility.log $logfac") if(-e "project_IP_facility.log");
		system("cp project_IP_Practitioner.log $loginp") if(-e "project_IP_Practitioner.log");
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
					print $imfofh $b . "\t" . $line . "\n";
				}
				close $imfifh;
				close $imfofh;
				system("rm " . $x . ".txt");
			}
		}
		
		#collect IP stats from log and lst files
		&collectIPstats($b);
#		}
#		elsif($b2type{$b} eq "NoProj")
#		{
#			system("sas -noterminal -memsize 4G $codedir/input_unproj.sas");
#			system("cp input_unproj.log $loginp") if(-e "input_unproj.log");
#			
#			#do we need some stats collection here?
#		}
		
		#save the bucket result if exists, else warn
		if(-e "hospital_projections.txt")
		{
			$bstats{$b}{HAVERES}=1;
			&saveResult("hospital_projections.txt","pxdxresult.txt","y");
			&saveResult("hospital_projections_nostar.txt","pxdxresultnostar.txt","y");
		}
		else
		{
			print "\tWARNING: no hospital_projections.txt result for |$b|\n";
			$bstats{$b}{HAVERES}=0;
		}
	}
	elsif($setting eq "OP")
	{
		if(defined $memoryHash->{"DNP_BUCKETS"}->{$b})
		{
			open(OUT,">>input.txt");
			print OUT "PROJECTOP\tN\n";
			close(OUT);
		}
		
		#save the lst and log
		my $lst=$b2.".lst";
		my $loginp=$b2.".log";
		
		#symlink the necessary files from project dir
		system("ln -s ../op_datamatrix.sas7bdat .");
		system("ln -s ../poid_attributes_op.sas7bdat .");
		system("ln -s ../op_poids.sas7bdat .");
		
		#run projections
#		if($b2type{$b} eq "Proj")
#		{
		system("sas -noterminal -memsize 4G $codedir/project_OP.sas");
		system("cp project_OP.log $loginp") if(-e "project_OP.log");
		system("cp project_OP.lst $lst") if(-e "project_OP.lst");
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
				print $imfofh $b . "\t" . $line . "\n";
			}
			close $imfifh;
			close $imfofh;
			system("rm " . "overall_factor.txt");
		}
		
		#collect OP stats from log files
		&collectOPstats($b);
#		}
#		elsif($b2type{$b} eq "NoProj")
#		{
#			system("ln -s ../op_poids.sas7bdat .");
#			system("sas -noterminal -memsize 4G $codedir/input_unproj_op.sas");
#			system("cp input_unproj_op.log $loginp") if(-e "input_unproj_op.log");
#		}
		
		#save the bucket result if exists, else warn
		if(-e "hospital_projections.txt")
		{
			$bstats{$b}{HAVERES}=1;
			&saveResult("hospital_projections.txt","pxdxresult.txt","y");
			&saveResult("hospital_projections_nostar.txt","pxdxresultnostar.txt","y");
		}
		else
		{
			print "\tWARNING: no hospital_projections.txt result for |$b|\n";
			$bstats{$b}{HAVERES}=0;
		}
	}
	elsif(($setting eq "Freestanding") || ($setting eq "OfficeASC"))
	{
		if(defined $memoryHash->{"DNP_BUCKETS"}->{$b})
		{
			open(OUT,">>input.txt");
			print OUT "PROJECTOFF\tN\n";
			print OUT "PROJECTASC\tN\n";
			close(OUT);
		}
		
		#save the lst and log
		my $lst_asc="asc_$b2.lst";
		my $log_asc="asc_$b2.log";
		my $lst_off="off_$b2.lst";
		my $log_off="off_$b2.log";
		
		#symlink the necessary files from project dir
		system("ln -s ../asc_datamatrix.sas7bdat .");
		
		#run office projections
		system("sas -noterminal -memsize 4G $codedir/project_Office.sas");
		system("cp project_Office.log $log_off") if(-e "project_Office.log");
		system("cp project_Office.lst $lst_off") if(-e "project_Office.lst");
		
		#collect stats from log and lst files for office
		&collectOfficestats($b);
		
		#check bucket result if exists, else warn
		if(-e "office_projections.txt")
		{
			$bstats{$b}{HAVEOFFRES}=1;
			
			#DEBUG
			#can disable saving office by itself after QC to old process is done
			#first put bucket name in 1st col
			#also calculate poid total to save
			my (%popicnt,%pocnt);
			open(INP,"office_projections.txt");
			while(<INP>)
			{
				chomp;
				if($. > 1)
				{
					my @f=split '\t';
					$popicnt{$f[1]}{$f[0]}+=$f[2];
					$pocnt{$f[1]}+=$f[2];
				}
			}
			close(INP);
			open(OUT,">office_projections_wb.txt");
			print OUT "Bucket\tHMS_PIID\tHMS_POID\tPractFacClaimCount\tFacClaimCount\n";
			foreach my $po (keys %popicnt)
			{
				foreach my $pi (keys %{$popicnt{$po}})
				{
					my @v;
					push @v,$b;
					push @v,$pi;
					push @v,$po;
					push @v,$popicnt{$po}{$pi};
					push @v,defined $pocnt{$po} ? $pocnt{$po} : "";
					my $str=join("\t",@v);
					print OUT "$str\n";
				}
			}
			close(OUT);
			
			&saveResult("office_projections_wb.txt","alloffice_nostar.txt","n");
		}
		else
		{
			print "\tWARNING: no office_projections.txt result for |$b|\n";
			$bstats{$b}{HAVEOFFRES}=0;
		}
		
		#run ASC projections
		system("sas -noterminal -memsize 4G $codedir/project_ASC.sas");
		system("cp project_ASC.log $log_asc") if(-e "project_ASC.log");
		system("cp project_ASC.lst $lst_asc") if(-e "project_ASC.lst");
		#collect stats from log and lst files for ASC
		&collectASCstats($b);
		
		#check bucket result if exists, else warn
		if(-e "asc_projections.txt")
		{
			$bstats{$b}{HAVEASCRES}=1;
			#DEBUG
			#can disable saving ASC by itself after QC to old process is done
			#first put bucket name in 1st col
			open(INP,"asc_projections.txt");
			open(OUT,">asc_projections_wb.txt");
			while(<INP>)
			{
				chomp;
				if($. == 1)
				{
					print OUT "Bucket\t$_\n";
				}
				elsif($. > 1)
				{
					print OUT "$b\t$_\n";
				}
			}
			close(INP);
			close(OUT);
			
			&saveResult("asc_projections_wb.txt","allasc_nostar.txt","n");
		}
		else
		{
			print "\tWARNING: no asc_projections.txt result for |$b|\n";
			$bstats{$b}{HAVEASCRES}=0;
		}
		
		#combine step for office and asc
		system("sas -noterminal -memsize 4G $codedir/combine_office_asc.sas");
		
		#save combined office + ASC bucket result if exists, else warn
		my $tgt=($jobtype eq "AB") ? "pxdxresult_nostar.txt" : "pxdxresultnostar.txt";
		if(-e "office_asc_projections.txt")
		{
			$bstats{$b}{HAVECOMBRES}=1;
			&saveResult("office_asc_projections.txt","pxdxresult.txt","n");
			&saveResult("office_asc_projections_nostar.txt",$tgt,"n");
		}
		else
		{
			print "\tWARNING: no office_asc_projection.txt result for |$b|\n";
			$bstats{$b}{HAVECOMBRES}=0;
		}
	}
	elsif($setting eq "SNF")
	{
		#save the stderrout
		my $log=$b2."_pacProjStdErr";
		
		open(OUT,">>input.txt");
		print OUT "PACSettings\tSNF\n";
		close(OUT);
		
		#run SNF projections
		system("perl $codedir/project_PAC.pl");
		system("cp pacProjStdErr $log");
		
		#save the bucket result if exists, else warn
		if(-e "pac_projections.txt")
		{
			#read the pac_projections.txt file, and build up the
			#pxdxresult.txt and pxdxresultnostar.txt - pay attention to
			#switching order of piid and poid columns
			$bstats{$b}{HAVERES}=1;
			open(PACRES,"pac_projections.txt");
			while(<PACRES>)
			{
				chomp;
				if($. > 1)
				{
					my @f=split '\t';
					my (@vst,@vnost);
					push @vst,$b;
					push @vst,$f[1];  #column switching
					push @vst,$f[0];
					push @vnost,$b;
					push @vnost,$f[1];  #column switching
					push @vnost,$f[0];
					#dont want the PractNatlProjCount column in result
					foreach my $i (2,4)
					{
						push @vnost,$f[$i];
						push @vst,($f[$i] < 11) ? 5.5 : $f[$i];
					}
					my $strst=join("\t",@vst);
					my $strnost=join("\t",@vnost);
					print SNFST "$strst\n";
					print SNFNOST "$strnost\n";
				}
			}
			close(PACRES);
		}
		else
		{
			print "\tWARNING: no pac_projections.txt result for |$b|\n";
			$bstats{$b}{HAVERES}=0;
		}
	}
}

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
if($setting eq "OP")
{
	if(-e "overall_factor.txt")
	{
		system("mv overall_factor_Final.txt overall_factor.txt");
		my @sf = qw/BUCKET/;
		my @ss = ("");
		MiscFunctions::sortTable(file=>"overall_factor.txt",sortFields=>\@sf,sortStyle=>\@ss);
	}
}
if($setting eq "SNF")
{
	close(SNFST);
	close(SNFNOST);
}

#output summary stats for each setting
if($setting =~ m/IP|OP/)
{
	open(OUT,">summaryinfo.txt");
	print OUT "Bucket\tLowpf\tMedpf\tHighpf\tTotalPoids\tNobs\t";
	print OUT "AllpClCnt\tCMSClCnt\tHaveRes\n";
	foreach my $b (keys %bstats)
	{
		my @v;
		push @v,$b;
		push @v,defined $bstats{$b}{LOWPF} ? $bstats{$b}{LOWPF} : "";
		push @v,defined $bstats{$b}{MEDPF} ? $bstats{$b}{MEDPF} : "";
		push @v,defined $bstats{$b}{HIGHPF} ? $bstats{$b}{HIGHPF} : "";
		push @v,defined $bstats{$b}{TOTPOIDS} ? $bstats{$b}{TOTPOIDS} : "";
		push @v,defined $bstats{$b}{NOBS} ? $bstats{$b}{NOBS} : "";
		push @v,defined $bstats{$b}{ALLPCL} ? $bstats{$b}{ALLPCL} : "";
		push @v,defined $bstats{$b}{CMSCL} ? $bstats{$b}{CMSCL} : "";
		push @v,defined $bstats{$b}{HAVERES} ? $bstats{$b}{HAVERES} : "";
		my $str=join("\t",@v);
		print OUT "$str\n";
	}
	close(OUT);
}
elsif($setting =~ m/OfficeASC|Freestanding/)
{
	open(OUT,">summaryinfo.txt");
	print OUT "Bucket\tOffMedPf\tOffNobs\tASCMedPf\tASCNobs\tHaveOffRes\t";
	print OUT "HaveASCRes\tHaveCombRes\n";
	foreach my $b (keys %bstats)
	{
		my @v;
		push @v,$b;
		push @v,defined $bstats{$b}{OFFMEDPF} ? $bstats{$b}{OFFMEDPF} : "";
		push @v,defined $bstats{$b}{OFFNOBS} ? $bstats{$b}{OFFNOBS} : "";
		push @v,defined $bstats{$b}{ASCMEDPF} ? $bstats{$b}{ASCMEDPF} : "";
		push @v,defined $bstats{$b}{ASCNOBS} ? $bstats{$b}{ASCNOBS} : "";
		push @v,defined $bstats{$b}{HAVEOFFRES} ? $bstats{$b}{HAVEOFFRES} : "";
		push @v,defined $bstats{$b}{HAVEASCRES} ? $bstats{$b}{HAVEASCRES} : "";
		push @v,defined $bstats{$b}{HAVECOMBRES} ? $bstats{$b}{HAVECOMBRES} : "";
		my $str=join("\t",@v);
		print OUT "$str\n";
	}
	close(OUT);
}
elsif($setting =~ m/PAC/)
{
}

sub collectIPstats
{
	my $b=shift;
	
	#collect some stats
	if(-e "2b_Facility_Counts.lst")
	{
		my $nobs=`grep -w "Number of Observations Used" 2b_Facility_Counts.lst | egrep -v "Training|Testing" | tail -1`;
		chomp($nobs);
		$nobs=~s/Number of Observations Used//g;
		$nobs=~s/^\s+//g;
		$nobs=~s/\s+$//g;
		$bstats{$b}{NOBS}=$nobs;
	}
	else
	{
		$bstats{$b}{NOBS}="";
	}
	
	if(-e "2b_Facility_Counts.log")
	{
		my $highpf=`grep highpf 2b_Facility_Counts.log | tail -1`;
		chomp($highpf);
		if(length($highpf) > 0)
		{
			my ($ju,$val)=split('\s+',$highpf);
			$bstats{$b}{HIGHPF}=$val;
		}
		else
		{
			$bstats{$b}{HIGHPF}="";
		}
		
		my $lowpf=`grep lowpf 2b_Facility_Counts.log | tail -1`;
		chomp($lowpf);
		if(length($lowpf) > 0)
		{
			my ($ju,$val)=split('\s+',$lowpf);
			$bstats{$b}{LOWPF}=$val;
		}
		else
		{
			$bstats{$b}{LOWPF}="";
		}
	}
	else
	{
		$bstats{$b}{LOWPF}="";
		$bstats{$b}{HIGHPF}="";
	}
	
	if(-e "input.log")
	{
		my $medpf=`grep median input.log | grep -v pf | tail -1`;
		chomp($medpf);
		if(length($medpf) > 0)
		{
			my ($ju,$val)=split(':',$medpf);
			$val=~s/\s+//g;
			$bstats{$b}{MEDPF}= ($val !~ m/factor/) ? $val : "";
		}
		else
		{
			$bstats{$b}{MEDPF}="";
		}
		
		#used to be like this in old AB, but the grep -v seems to cause issues
		#my $allpcl=`grep Total input.log | grep claims | grep allpayer | grep -v \&`;
		my $allpcl=`grep Total input.log | grep claims | grep allpayer`;
		chomp($allpcl);
		if(length($allpcl) > 0)
		{
			my ($ju,$val)=split(':',$allpcl);
			$val=~s/\s+//g;
			$bstats{$b}{ALLPCL}= ($val !~ m/all/) ? $val : "";
		}
		else
		{
			$bstats{$b}{ALLPCL}="";
		}
		
		my $cmscl=`grep Total input.log | grep claims | grep cms`;
		chomp($cmscl);
		if(length($cmscl) > 0)
		{
			my ($ju,$val)=split(':',$cmscl);
			$val=~s/\s+//g;
			$bstats{$b}{CMSCL}=$val;
		}
		else
		{
			$bstats{$b}{CMSCL}="";
		}
	}
	else
	{
		$bstats{$b}{CMSCL}="";
		$bstats{$b}{ALLPCL}="";
		$bstats{$b}{MEDPF}="";
	}
}

sub saveResult
{
	my $inpf=$_[0];
	my $outf=$_[1];
	my $removecol5=$_[2];
	
	if(-e $outf)
	{
		if($removecol5 eq "y")
		{
			system("tail -n +2 $inpf | cut -f1-4,6- >> $outf");
		}
		else
		{
			system("tail -n +2 $inpf >> $outf");
		}
	}
	else
	{
		if($removecol5 eq "y")
		{
			system("cut -f1-4,6- $inpf > $outf");
		}
		else
		{
			system("cp $inpf $outf");
		}
	}
}

sub collectOPstats
{
	my $b=shift;
	
	if(-e "input_op.log")
	{
		my $highpf=`grep "max estimated factor" input_op.log`;
		chomp($highpf);
		if(length($highpf) > 0)
		{
			my ($ju,$val)=split(':',$highpf);
			$val=~s/\s+//g;
			$bstats{$b}{HIGHPF}=$val;
		}
		else
		{
			$bstats{$b}{HIGHPF}="";
		}
		
		my $medpf=`grep "median estimated factor" input_op.log | grep -v pf | tail -1`;
		chomp($medpf);
		if(length($medpf) > 0)
		{
			my ($ju,$val)=split(':',$medpf);
			$val=~s/\s+//g;
			$bstats{$b}{MEDPF}= ($val !~ m/factor/) ? $val : "";
		}
		else
		{
			$bstats{$b}{MEDPF}="";
		}
		
		my $lowpf=`grep "min estimated factor" input_op.log | grep -v pf | tail -1`;
		chomp($lowpf);
		if(length($lowpf) > 0)
		{
			my ($ju,$val)=split(':',$lowpf);
			$val=~s/\s+//g;
			$bstats{$b}{LOWPF}= ($val !~ m/factor/) ? $val : "";
		}
		else
		{
			$bstats{$b}{LOWPF}="";
		}
		
		my $totpoid=`grep number input_op.log | grep observations | grep Total`;
		chomp($totpoid);
		if(length($totpoid)> 0)
		{
			my ($ju,$val)=split(':',$totpoid);
			$val=~s/\s+//g;
			$bstats{$b}{TOTPOIDS}=($val !~ m/obs/) ? $val : "";
		}
		else
		{
			$bstats{$b}{TOTPOIDS}="";
		}
		
		my $allpcl=`grep Total input_op.log | grep counts | grep allpayer`;
		chomp($allpcl);
		if(length($allpcl) > 0)
		{
			my ($ju,$val)=split(':',$allpcl);
			$val=~s/\s+//g;
			$bstats{$b}{ALLPCL}= ($val !~ m/all/) ? $val : "";
		}
		else
		{
			$bstats{$b}{ALLPCL}="";
		}
		
		my $cmscl=`grep Total input_op.log | grep counts | grep cms`;
		chomp($cmscl);
		if(length($cmscl) > 0)
		{
			my ($ju,$val)=split(':',$cmscl);
			$val=~s/\s+//g;
			$bstats{$b}{CMSCL}=($val !~ m/cms/) ? $val : "";
		}
		else
		{
			$bstats{$b}{CMSCL}="";
		}
	}
	
	if(-e "input_op.lst")
	{
		my $nobs=`grep -w "Number of Observations Used" input_op.lst`;
		chomp($nobs);
		$nobs=~s/Number of Observations Used//g;
		$nobs=~s/^\s+//g;
		$nobs=~s/\s+$//g;
		$bstats{$b}{NOBS}=$nobs;
	}
}

sub collectOfficestats
{
	my $b=shift;
	
	my $medpf=`egrep "^Median" project_Office.log`;
	chomp($medpf);
	if(length($medpf) > 0)
	{
		my ($ju,$val)=split('=',$medpf);
		$val=~s/\s+//g;
		$bstats{$b}{OFFMEDPF}= $val;
	}
	else
	{
		$bstats{$b}{OFFMEDPF}="";
	}
	
	my $nobs=`grep -w "Number of Observations Used" project_Office.lst | tail -1`;
	chomp($nobs);
	$nobs=~s/Number of Observations Used//g;
	$nobs=~s/^\s+//g;
	$nobs=~s/\s+$//g;
	$bstats{$b}{OFFNOBS}=$nobs;
}

sub collectASCstats
{
	my $b=shift;
	
	my $medpf=`egrep "^Median_pf_phys" new_asc_projections.log | tail -1`;
	chomp($medpf);
	if(length($medpf) > 0)
	{
		my ($ju,$val)=split('=',$medpf);
		$val=~s/\s+//g;
		$bstats{$b}{ASCMEDPF}= $val;
	}
	else
	{
		$bstats{$b}{ASCMEDPF}="";
	}
	
	my $nobs=`grep -w "Number of Observations Used" new_asc_projections.lst | tail -1`;
	chomp($nobs);
	$nobs=~s/Number of Observations Used//g;
	$nobs=~s/^\s+//g;
	$nobs=~s/\s+$//g;
	$bstats{$b}{ASCNOBS}=$nobs;
}


