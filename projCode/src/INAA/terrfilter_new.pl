#!/usr/bin/perl -w
use DBI;
use strict;

#4.10.2017
#changes to use Steve's copy of decile script, and move everything to
#HGWorkflow from Dilip's personal U drive
#this is Steve's decile script: /vol/cs/CHAMPS_Technical/hms_delivery/bin/decile
#this filter script calls several other things located in the same dir as
# the filter script:
#terrrankonlylinks.sas
#star.R
#calcdenommedianmean.sas
# and makeidlist.R has to be run before running this script

#1.18.2016
#modifications to handle super large all codes filters
#used to fail when system calls not executed for super large networks
#first big change:
#link count, natl rank, and terr rank combined into a single hash
#with colon separate values.  functions at bottom return the appropriate
#value from the colon separated structure, given a link key
#this makes the sort on link count before writing network.txt 30% slower.  
#if this becomes an issue, the link count can be pulled out and put
#in a separate hash
#second big change:
#moved all use of inc and outc to before first system call and they
#are undef before the call
#this means the 2 passes through rankdedenom have been combined into 1
#with natl and terr count files being written in same pass through this file
# vs 2 passes in prior versions
#all checks of whether or not in network that used to be done with check
#on inc or outc are now done with check to id2cnt


#8.3.2015
#all output files will have _grp1_ and _grp2_ in name going forward
#for backward compatibility, input file will support the old way
# and newer way of _grp1 and _grp2

#3.27.2015
#handle poids in the networks on either side
#no longer assume that grp1 is dx and grp2 is px
#so relabel dx as grp1 and px as grp2

#2.22.2015
#deal with the fact that both exact and range appear in QA/pxdx.tab
#and neither has the hybrid workload from milestones/pxdx.tab that we want
#to deliver in direct tab file deliveries
#approach:  continue to output the filtered QA/pxdx.tab as pxdx_filtered.tab
#and read the milestones/pxdx.tab and output filtered version of this as
# pxdx_fordelivery.tab
#star.R will read _filtered, and output it as _forbiltmore after starring
# star.R will not do anything to the _fordelivery version
# the makeview.R code will take the _forbiltmore version and convert the
# exact workload and convert to 0-10, 10-20, etc as 1,2,...

#12.1.2014
#update to allow option "Both" to be specified for Relational
#this produces both the full and relational network versions


#8.28.2014
#run star.R in more scenarios - e.g. no decil col specified, but
#orgs or affils files specified from QA directory

#2.2.2014
#add capability to produce filtered pxdx and orgs file for both dx and px
#files in dx->px networks.  prior to this, only the dx files were considered

#9.30.2013
#if pxdx counts/ranks are specified via the filter and univ files
#force all docs in filter file to show up in rerank files, and indiv_filtered
#file, and use full piid list to be used for filtering the affils file,
#and subsquently the orgs file
#i.e. don't restrict the above files to filter list docs who only appear in the
#network - as it used to be

#8.24.2013
#provide terr rank for orgs file
#output indivs filtered file even if pxdx not being integrated
#add share patient specification option via input file, in addition to argu

#upgrades:
#07.23.2013
#allow option to produce network file without profile info - dump that
#in a separate file
#
#02.12.2013
#putting mapped SOR values into median/mean files
#decided not to rerank national SOR counts, even if universe is specified
# - too much work, for probably little impact
# require sor map values to not be merged

#02.01.2013
#enable filtering of a pxdx affils and pxdx orgs file to terr

#12.12.2012
#added mean/median calc for the denoms - need it in case of reranking  of 
#national, or terr rank

#12.12.2012 - fixed the problem that pxdx ranks being read only for the
#filter or the univ file, not from both - results in records suppressed 

#prior fix:  suppress output of any edge mapped to label starting with 0

my $dbhA = DBI->connect('DBI:Oracle:PLDELDB','hms_pe','hms_pe123')
  or die "could not connect to database: ".DBI->errstr;

#usage:  perl terrfilter_new.pl inputparametersfile
#secret option addcounts after input file name - is optional

#set the codedir to Prod_NewWH, then check $0 to see if it should be Dev
my $codedir="/vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA";
if($0 =~ m/\/Dev\//)
{
 $codedir="/vol/datadev/Statistics/Projects/HGWorkFlow/Dev/INA";
}
my $deciledir="/vol/cs/CHAMPS_Technical/hms_delivery/bin";

if(-e "done.txt")
{
 system("rm done.txt");
}

#figure out how many denom bins wanted
my $dbins=`grep DenomBins ../../inputs | cut -f2`;
chomp($dbins);
$dbins = (length($dbins) > 0) ? $dbins : 10; #default is 10

#need to also set SORBIN before calling SAS
my $sorbins=`grep SORBins ../../inputs | cut -f2`;
chomp($sorbins);
$sorbins = (length($sorbins) > 0) ? $sorbins : 5; #default is 5
$ENV{SORBIN}=$sorbins;

my $vint=`grep Vintage ../../inputs | cut -f2`;
chomp($vint);

#figure out the number of groups in the analysis - i.e 1 or 2
my $ngr=1;
if(-e "../../codes")
{
 #based on number of different keys in the 1st column of codes
 $ngr = `cut -f1 ../../codes | grep -v Group | sort -u | wc -l`;
}
elsif(-e "../../inputs")
{
 #based on Groups value in inputs file - for new WH
 $ngr = `grep Groups ../../inputs | cut -f2`;
}
else
{
 #if no codes, it is all codes, and that is 1 group
 $ngr=1;
}
chomp($ngr);
$ngr+=0;
$ENV{NGR}=$ngr;

#figure out what type of entities on both sides - i.e. PIID or POID
#for backward compatibility, default is both PIID
my $grp1ent="PI";
my $grp2ent=($ngr == 2) ? "PI" : "";
if(-e "../../inputs")
{
 my $str=`grep Grp1Ent ../../inputs | cut -f2`;
 chomp($str);
 $grp1ent = $str if(length($str) == 2);
 if($ngr == 2)
 {
  my $str=`grep Grp2Ent ../../inputs | cut -f2`;
  chomp($str);
  $grp2ent = $str if(length($str) == 2);
 }
}
print "number of groups in analysis = |$ngr|\n";
print "Group1 type is |$grp1ent|\n";
print "Group2 type is |$grp2ent|\n" if($ngr == 2);

#figure out what the keys are for the filter file and the second file
# e.g. if group 1 is piid: 
# the filter key is HMS_PIID
# the filter file is indivs
# the second key in the affils file is HMS_POID
# the second (or other file) to filter via the affils file is the orgs file

my $grp1filtkey="HMS_".$grp1ent."ID";
my $grp1secondkey="";
my $grp1filtfile_o="";  #what the filter file is going to be called on output
my $grp1secondfile_o=""; #what the 2nd file is going to be called on output
if($grp1ent eq "PI")
{
 $grp1secondkey="HMS_POID";
 $grp1filtfile_o="indivs_grp1_filtered.tab";
 $grp1secondfile_o="orgs_grp1_filtered.tab";
}
elsif($grp1ent eq "PO")
{
 $grp1secondkey="HMS_PIID";
 $grp1filtfile_o="orgs_grp1_filtered.tab";
 $grp1secondfile_o="indivs_grp1_filtered.tab";
}
print "Group 1 filter list key = |$grp1filtkey|\n";
print "Group 1 second file key = |$grp1secondkey|\n";
print "Group 1 filter file output = |$grp1filtfile_o|\n";
print "Group 1 second file output = |$grp1secondfile_o|\n";

my $grp2filtkey="";
my $grp2secondkey="";
my $grp2filtfile_o="";
my $grp2secondfile_o="";
if($ngr == 2)
{
 $grp2filtkey="HMS_".$grp2ent."ID";
 if($grp2ent eq "PI")
 {
  $grp2secondkey="HMS_POID";
  $grp2filtfile_o="indivs_grp2_filtered.tab";
  $grp2secondfile_o="orgs_grp2_filtered.tab";
 }
 elsif($grp2ent eq "PO")
 {
  $grp2secondkey="HMS_PIID";
  $grp2filtfile_o="orgs_grp2_filtered.tab";
  $grp2secondfile_o="indivs_grp2_filtered.tab";
 }
 print "Group 2 filter list key = |$grp2filtkey|\n";
 print "Group 2 second file key = |$grp2secondkey|\n";
 print "Group 2 filter file output = |$grp2filtfile_o|\n";
 print "Group 2 second file output = |$grp2secondfile_o|\n";
}

my $addcnts="N";
print "number of arguments = ",scalar(@ARGV),"\n";
my $str=join("\t",@ARGV);
print "Arguments = $str\n";
if(scalar(@ARGV) >= 2)
{
 $addcnts="Y" if($ARGV[1] =~ m/addcounts/i);
}

my $pf;
if(scalar(@ARGV) < 1)
{
 print "enter input parameters file\n";
 exit;
}
else
{
 $pf=$ARGV[0];
}

#read the parameters file
open(INP,$pf) or die "cant open $pf for read\n";
my (%sormap,%sormappedvals);
my $grp1filterfile="";
my $grp2filterfile="";
my $grp1decilecol="";
my $grp2decilecol="";
my $grp1countcol="";
my $grp2countcol="";
my $grp1univfile="";
my $grp2univfile="";
my $grp1affilsfile="";
my $grp1secondfile="";
my $grp2affilsfile="";
my $grp2secondfile="";
my $grp1secondfile_countcol="";
my $grp2secondfile_countcol="";
my $relational="n";
my $have0sormap="n";
while(<INP>)
{
 chomp;
 s/\015//g;
 next if(m/^#/);
 my $line=$_;
 $line=~s/\s+//g;
 next if(length($line) == 0);  #skip blank lines
 my @f=split '\t';
 foreach my $i (0 .. $#f)
 {
  $f[$i]=~s/^\s+//;
  $f[$i]=~s/\s+$//;
 }
 if($f[0] =~ m/strengthmap/i)
 {
  $sormap{$f[1]}=$f[2];
  $sormappedvals{$f[2]}++;
  $have0sormap="y" if($f[2] =~ m/^0/);
 }
 elsif($f[0] =~ m/grp1filter/i || $f[0] =~ m/dxfilter/i)
 {
  $grp1filterfile=$f[1] if($#f >= 1);
  $grp1decilecol=$f[2] if($#f >= 2);
  $grp1countcol=$f[3] if($#f >= 3);
 }
 elsif($f[0] =~ m/grp2filter/i || $f[0] =~ m/pxfilter/i)
 {
  $grp2filterfile=$f[1] if($#f >= 1 && $f[1] ne "");
  $grp2decilecol=$f[2] if($#f >= 2);
  $grp2countcol=$f[3] if($#f >= 3);
 }
 elsif($f[0] =~ m/grp1univ/i || $f[0] =~ m/dxuniv/i)
 {
  $grp1univfile=$f[1] if($#f >= 1);
 }
 elsif($f[0] =~ m/grp2univ/i || $f[0] =~ m/pxuniv/i)
 {
  $grp2univfile=$f[1] if($#f >= 1);
 }
 elsif(lc($f[0]) eq "pxdxaffils" || lc($f[0]) eq "pxdxaffils_grp1")
 {
  $grp1affilsfile=$f[1] if($#f >= 1);
 }
 elsif(lc($f[0]) eq "pxdxorgfile" || lc($f[0]) eq "pxdxsecondfile_grp1")
 {
  $grp1secondfile=$f[1] if($#f >= 1);
  $grp1secondfile_countcol=$f[2] if($#f >= 2);
 }
 elsif(lc($f[0]) eq "pxdxaffils_px" || lc($f[0]) eq "pxdxaffils_grp2")
 {
  $grp2affilsfile=$f[1] if($#f >= 1);
 }
 elsif(lc($f[0]) eq "pxdxorgfile_px" || lc($f[0]) eq "pxdxsecondfile_grp2")
 {
  $grp2secondfile=$f[1] if($#f >= 1);
  $grp2secondfile_countcol=$f[2] if($#f >= 2);
 }
 elsif($f[0] =~ m/Relational/i)
 {
  $relational= lc $f[1] if($#f >= 1);
 }
 elsif($f[0] =~ m/AddCounts/i)
 {
  if($#f >= 1)
  {
   if($f[1] =~ m/y/i)
   {
    $addcnts="Y";
   }
  }
 }
}
close(INP);
print "done reading parameters\n";
print "addcnts value is |$addcnts|\n";
print "group 1 counts col = |$grp1countcol|\n";
print "group 1 decile col = |$grp1decilecol|\n";
if($ngr == 2)
{
 print "group 2 counts col = |$grp2countcol|\n";
 print "group 2 decile col = |$grp2decilecol|\n";
}



#check the mapped values for uniqueness
foreach my $v (keys %sormappedvals)
{
 if($sormappedvals{$v} > 1)
 {
  print "multiple Strength values map to Label |$v|\n";
  print "please specify a unique mapping and rerun\n";
  print "exiting\n";
  exit;
 }
}

#output the SOR map values to file to use in SAS
open(OUTS,">sormap.txt");
print OUTS "lq\tSOR\n";
foreach my $s (keys %sormap)
{
 print OUTS "$s\t$sormap{$s}\n";
}
close(OUTS);


#read the grp1 id list
my %wantidgrp1;
my $wantidgrp1ref=\%wantidgrp1;
if($grp1filterfile ne "")
{
 &readidfile($wantidgrp1ref,$grp1filterfile,$grp1decilecol,$grp1countcol,$grp1ent);
 print "done reading grp1 id list\n";
 print "number of grp1fitler ids = ",scalar(keys %$wantidgrp1ref),"\n";
}
if(scalar(keys %wantidgrp1) == 0 && $grp1filterfile ne "")
{
 print "could not read docs from grp1 filter file\n";
 print "not applying this grp1 doc filter\n";
 $grp1filterfile="";
}

#read the grp2 id list
my %wantidgrp2;
my $wantidgrp2ref=\%wantidgrp2;
if($grp2filterfile ne "")
{
 &readidfile($wantidgrp2ref,$grp2filterfile,$grp2decilecol,$grp2countcol,$grp2ent);
 print "done reading grp2 id list\n";
}
if(scalar(keys %wantidgrp2) == 0 && $grp2filterfile ne "")
{
 print "could not read docs from grp2 filter file\n";
 print "not applying this grp2 id filter\n";
 $grp2filterfile="";
}

#make sure we have either a grp1filter file or a grp2filter file
if($grp1filterfile eq "" && $grp2filterfile eq "")
{
 print "you must specify either a grp1 filter file or a grp2 filter file\n";
 print "exiting\n";
 exit;
}

#read the grp1 universe list
my %grp1universe;
my $grp1universeref=\%grp1universe;
if($grp1univfile ne "")
{
 &readidfile($grp1universeref,$grp1univfile,$grp1decilecol,$grp1countcol,$grp1ent);
 print "number of grp1univ ids= ",scalar(keys %$grp1universeref),"\n";
 print "done reading Grp1 universe of ids\n";
}
if(scalar(keys %grp1universe) == 0 && $grp1univfile ne "")
{
 print "could not read docs from grp1 id universe file\n";
 print "not applying the grp1 universe criterion\n";
 $grp1univfile="";
}
#read the grp2 universe list
my %grp2universe;
my $grp2universeref=\%grp2universe;
if($grp2univfile ne "")
{
 &readidfile($grp2universeref,$grp2univfile,$grp2decilecol,$grp2countcol,$grp2ent);
 print "done reading Grp2 universe of ids\n";
}
if(scalar(keys %grp2universe) == 0 && $grp2univfile ne "")
{
 print "could not read docs from grp2 id universe file\n";
 print "not applying the grp2 universe criterion\n";
 $grp2univfile="";
}


#read the fips code to county name map
my $fipf="/vol/datadev/Statistics/SAS/lookup/fips.csv";
open(FIPS,$fipf) or die "cant open $fipf\n";
my %fip2cnty;
while(<FIPS>)
{
 chomp;
 s/\015//g;
 next if(m/^State/);
 my @f=split ',';
 my $k=$f[1].$f[2];
 $fip2cnty{$k}=$f[3];
}
close(FIPS);

#read links and denom from above, and store and output filtered version
my (%outc,%inc,%linkcntwrank);
my %wantid; #list of docs to grab profiles for
open(INPL,"../links.txt") or die "cant open ../links.txt\n";
open(OUT1,">links2rerank.txt");
print OUT1 "Link\tCount\n";
LINK: while(<INPL>)
{
 chomp;
 next if(m/^VAR1/i);
 my @f=split '\t';
 my @g=split(':',$f[0]);
 #filtering logic depends on the inputs and number of groups
 if($ngr == 1)
 {
  #either doc must be on grp1 filter list
  next LINK unless(defined $wantidgrp1{$g[0]} || defined $wantidgrp1{$g[1]});
 }
 elsif($ngr == 2)
 {
  if($grp2filterfile ne "")
  {
   next LINK unless(defined $wantidgrp2{$g[1]});
  }
  if($grp1filterfile ne "")
  {
   next LINK unless(defined $wantidgrp1{$g[0]});
  }
 }
 else
 {
  print "problem number of groups = |$ngr|\n";
  exit;
 }
 #if universe specified - both docs must be in universe
 if($ngr == 1)
 {
  if($grp1univfile ne "")
  {
   next LINK unless(defined $grp1universe{$g[0]} && defined $grp1universe{$g[1]});
  }
 }
 elsif($ngr == 2)
 {
  if($grp1univfile ne "")
  {
   next LINK unless(defined $grp1universe{$g[0]});
  }
  if($grp2univfile ne "")
  {
   next LINK unless(defined $grp2universe{$g[1]});
  }
 }
 $outc{$g[0]}{$g[1]}=$f[1];
 $inc{$g[1]}{$g[0]}=$f[1];
 $linkcntwrank{$f[0]}=$f[1].":".$f[2];
 print OUT1 "$g[0]:$g[1]\t$f[1]\n";
 $wantid{$g[0]}++;
 $wantid{$g[1]}++;
}
close(INP);
close(OUT1);
print "done reading links from above\n";

#add ids to wantid who are not in geography, but are connected to ids
#in geography - so that we can grab their profiles
foreach my $id1 (keys %outc)
{
 $wantid{$id1}++;
 foreach my $id2 (keys %{$outc{$id1}})
 {
  $wantid{$id2}++;
 }
}

#calculate pharma decile rank for counts in ../rankeddenom.txt
#need this step in case we are producing a network file independent of any pxdx
#if we are doing pxdx-based filtering and rank col is specified for the indiv
#  then that rank will be used instead of what is calculated here
#first produce id->counts files with count for every id

my (%id2cnt,%id2natrank);
open(INP,"../rankeddenom.txt") or die "cant open ../rankeddenom.txt\n";
open(OUT1,">grp1cnt.txt");
open(OUT2,">grp2cnt.txt") if($ngr == 2);
print OUT1 "HMS_ID\tGrp1Cnt\n";
print OUT2 "HMS_ID\tGrp2Cnt\n" if($ngr == 2);
#also output files for terr reranking
#use the pxdx counts if available, else the infl net denom counts
open(OUT3,">grp1forrerank.txt");
print OUT3 "HMS_ID\tGrp1Cnt\n";
open(OUT4,">grp2forrerank.txt") if($ngr == 2);
print OUT4 "HMS_ID\tGrp2Cnt\n" if($ngr == 2);
while(<INP>)
{
 chomp;
 next if(m/^HMS_/);
 my @f=split '\t';
 print OUT1 "$f[0]\t$f[1]\n" if($f[1] ne "");
 print OUT2 "$f[0]\t$f[2]\n" if($f[2] ne "" && $ngr == 2);
 if(defined $outc{$f[0]} || defined $inc{$f[0]})
 {
  if($ngr==1)
  {
   $id2cnt{$f[0]}{B}=$f[1];
  }
  elsif($ngr == 2)
  {
   $id2cnt{$f[0]}{1}=$f[1];
   $id2cnt{$f[0]}{2}=$f[2];
  }
 }
 #data for terr reranking
 if(defined $outc{$f[0]} || defined $inc{$f[0]})
 {
  if($ngr==1)
  {
   my $c=&getcount($f[0],$f[1],1);
   print OUT3 "$f[0]\t$c\n" if(defined $c);
  }
  elsif($ngr == 2)
  {
   if(defined $outc{$f[0]})
   {
    my $c1=&getcount($f[0],$f[1],1);
    print OUT3 "$f[0]\t$c1\n" if(defined $c1);
   }
   if(defined $inc{$f[0]})
   {
    my $c2=&getcount($f[0],$f[2],2);
    print OUT4 "$f[0]\t$c2\n" if(defined $c2);
   }
  }
 }
}
close(INP);
close(OUT1);
close(OUT2);
#if pxdx counts specified for either grp1 or grp2, make sure all ids in those
#files that dont appear in network are included in reranking
if($grp1decilecol ne "")
{
 foreach my $id (keys %$wantidgrp1ref)
 {
  next if($id =~m/HMS_/);
  if($ngr == 1)
  {
   if(!defined $outc{$id} && !defined $inc{$id})
   {
    print OUT3 "$id\t$wantidgrp1ref->{$id}->{Count}\n";
   }
  }
  elsif($ngr == 2)
  {
   if(!defined $outc{$id})
   {
    print OUT3 "$id\t$wantidgrp1ref->{$id}->{Count}\n";
   }
  }
 }
}
if($ngr == 2 && $grp2decilecol ne "")
{
 foreach my $id (keys %$wantidgrp2ref)
 {
  next if($id =~ m/HMS_/);
  if(!defined $inc{$id})
  {
   print OUT4 "$id\t$wantidgrp2ref->{$id}->{Count}\n";
  }
 }
}
close(OUT3);
close(OUT4);

#do the percent calculations using inc and outc
#first calculate number of shared pats per doctor
#for 2-group networks, allow count of shared pats in, and out
my (%id2shrptcnt,%id2shrptcntin,%id2shrptcntout);
foreach my $id (keys %id2cnt)
{
 my $sout=0;
 foreach my $id2 (keys %{$outc{$id}})
 {
  #print "$id\t$id2\t$outc{$id}{$id2}\n";
  $sout+=$outc{$id}{$id2};
 }
 my $sin=0;
 foreach my $id2 (keys %{$inc{$id}})
 {
  #print "$id2\t$id\t$inc{$id}{$id2}\n";
  $sin+=$inc{$id}{$id2};
 }
 if($ngr==1)
 {
  $id2shrptcnt{$id}=$sin+$sout;
 }
 elsif($ngr==2)
 {
  $id2shrptcntin{$id}=$sin;
  $id2shrptcntout{$id}=$sout;
 }
}

#do the local degree calculation
my %id2terrneigh;
foreach my $id (keys %id2cnt)
{
 if($ngr == 1)
 {
  my $deg=0;
  $deg += (defined $inc{$id}) ? scalar(keys %{$inc{$id}}) : 0;
  $deg += (defined $outc{$id}) ? scalar(keys %{$outc{$id}}) : 0;
  $id2terrneigh{$id}{B}=$deg; #this is total number of neigh in undirected net
 }
 elsif($ngr == 2)
 {
  $id2terrneigh{$id}{1} = defined $outc{$id} ? scalar(keys %{$outc{$id}}) : 0;  #this is number of group 2 docs connected to each group 1 id
  $id2terrneigh{$id}{2} = defined $inc{$id} ? scalar(keys %{$inc{$id}}) : 0;  #this is number of group 1 docs connected to each group 2 id
 }
}

#undef inc and outc to try and avoid the memory issue
%inc=();
%outc=();

#now call the HMS decile script to calculate the national ranks
#unless national ranks are to be read from indivs file
#and do mean/median table if reranking was done
if($grp1decilecol eq "")
{
 system("perl $deciledir/decile --in grp1cnt.txt --out grp1rank.txt --group NONE --atom HMS_ID --score Grp1Cnt --ncile $dbins");
 if(-e "decileranksoutput.txt")
 {
  system("rm decileranksoutput.txt");
 }
 system("ln -s grp1rank.txt decileranksoutput.txt");
 system("rm calcdenommedianmean.log") if(-e "calcdenommedianmean.log");
 system("sas -noterminal $codedir/calcdenommedianmean.sas");
 system("mv medmean.txt grp1natldensummary.txt");
 print "done recalculating grp1 national ranks using influence network counts\n"
}
if($ngr == 2)
{
 if($grp2decilecol eq "")
 {
  system("perl $deciledir/decile --in grp2cnt.txt --out grp2rank.txt --group NONE --atom HMS_ID --score Grp2Cnt --ncile $dbins");
  if(-e "decileranksoutput.txt")
  {
   system("rm decileranksoutput.txt");
  }
  system("ln -s grp2rank.txt decileranksoutput.txt");
 system("rm calcdenommedianmean.log") if(-e "calcdenommedianmean.log");
  system("sas -noterminal $codedir/calcdenommedianmean.sas");
  system("mv medmean.txt grp2natldensummary.txt");
 print "done recalculating grp2 national ranks using influence network counts\n"
 }
}

#now read the deciles produced by decile script, or from natl file 
#    - group 1 first
my $k = ($ngr == 1) ? "B" : "1";
if($grp1decilecol eq "")
{
 open(INP1,"grp1rank.txt") or die "no group 1 national rank file grp1rank.txt exists\n";
 while(<INP1>)
 {
  chomp;
  next if(m/HMS_/);
  my @f=split '\t';
  if(defined $id2cnt{$f[1]})
  {
   $id2natrank{$f[1]}{$k}=$f[4];
  }
 }
 close(INP1);
}
else
{
 #if reading from a PxDx national indivs file, need to figure out 
 #whether to read the filter file - 1st choice, or universe file
 #actually need to read from both files to enable records to be output
 if(scalar(keys %wantidgrp1) > 0)
 {
  foreach my $id (keys %wantidgrp1)
  {
   if(defined $id2cnt{$id})
   {
    $id2natrank{$id}{$k}=$wantidgrp1{$id}{Rank};
   }
  }
 }
 if(scalar(keys %grp1universe) > 0)
 {
  foreach my $id (keys %grp1universe)
  {
   if(defined $id2cnt{$id} && !defined $id2natrank{$id}{$k})
   {
    $id2natrank{$id}{$k}=$grp1universe{$id}{Rank};
   }
  }
 }
}

#now group 2
if($ngr==2)
{
 if($grp2decilecol eq "")
 {
  open(INP2,"grp2rank.txt") or die "no group 2 national rank file grp2rank.txt exists\n";
  while(<INP2>)
  {
   chomp;
   next if(m/HMS_/);
   my @f=split '\t';
   if(defined $id2cnt{$f[1]})
   {
    $id2natrank{$f[1]}{2}=$f[4];
   }
  }
  close(INP2);
 }
 else
 {
  if(scalar(keys %wantidgrp2) > 0)
  {
   foreach my $id (keys %wantidgrp2)
   {
    if(defined $id2cnt{$id})
    {
     $id2natrank{$id}{2}=$wantidgrp2{$id}{Rank};
    }
   }
  }
  if(scalar(keys %grp2universe) > 0)
  {
   foreach my $id (keys %grp2universe)
   {
    if(defined $id2cnt{$id}
                  && !defined $id2natrank{$id}{2})
    {
     $id2natrank{$id}{2}=$grp2universe{$id}{Rank};
    }
   }
  }
 }
}
print "done with national denom deciles\n";

#now calculate the territory ranks
#call the HMS decile script for the territory ranks
#and do the mean/median on the ranks output
system("perl $deciledir/decile --in grp1forrerank.txt --out grp1rerank.txt --group NONE --atom HMS_ID --score Grp1Cnt --ncile $dbins");
if(-e "decileranksoutput.txt")
{
 system("rm decileranksoutput.txt");
}
system("ln -s grp1rerank.txt decileranksoutput.txt");
 system("rm calcdenommedianmean.log") if(-e "calcdenommedianmean.log");
system("sas -noterminal $codedir/calcdenommedianmean.sas");
system("mv medmean.txt grp1terrdensummary.txt");
if($ngr == 2)
{
 system("perl $deciledir/decile --in grp2forrerank.txt --out grp2rerank.txt --group NONE --atom HMS_ID --score Grp2Cnt --ncile $dbins");
 if(-e "decileranksoutput.txt")
 {
  system("rm decileranksoutput.txt");
 }
 system("ln -s grp2rerank.txt decileranksoutput.txt");
 system("rm calcdenommedianmean.log") if(-e "calcdenommedianmean.log");
 system("sas -noterminal $codedir/calcdenommedianmean.sas");
 system("mv medmean.txt grp2terrdensummary.txt");
}

#now read the territory deciles produced above - group 1 first
my %id2terrrank;
open(INP1,"grp1rerank.txt") or die "no group 1 terr rank file grp1rerank.txt exists\n";
while(<INP1>)
{
 chomp;
 next if(m/HMS_/);
 my @f=split '\t';
 $id2terrrank{$f[1]}{$k}=$f[4];
}
close(INP1);

#now group 2
if($ngr==2)
{
 open(INP2,"grp2rerank.txt") or die "no group 2 terr rank file grp2rerank.txt exists\n";
 while(<INP2>)
 {
  chomp;
  next if(m/HMS_/);
  my @f=split '\t';
  $id2terrrank{$f[1]}{2}=$f[4];
 }
 close(INP2);
}
print "done calculating territory ranks\n";

#need to read denom_fordelivery to get the national neighbor count
open(INPD2,"../denom_fordelivery.txt") or die "cant open denom_fordelivery.txt\n";
my %id2natneigh;
while(<INPD2>)
{
 chomp;
 next if(m/^HMS_/);
 my @f=split '\t';
 if($ngr==1)
 {
  $id2natneigh{$f[0]}{B}=$f[2];
 }
 elsif($ngr == 2)
 {
  $id2natneigh{$f[0]}{1}=$f[3];
  $id2natneigh{$f[0]}{2}=$f[4];
 }
}
close(INPD2);

#now run a sas job to do the ranking on the territory links file
system("sas -memsize 8G -noterminal $codedir/terrrankonlylinks.sas");

print "done with reranking links counts in SAS\n";

#now convert the national linksummarycount.txt file to have SOR mapped values
#assumes no merging of sor values was done in mapping
open(INP1,"../linksummarycounts.txt") or die "cant open ../linksummarycounts.txt
\n";
open(OUT1,">natllinksummarycount.txt");
while(<INP1>)
{
 chomp;
 if(m/^cq/)
 {
  print OUT1 "SOR\tCOUNT\tMEDIAN\tMEAN\tMIN\tMAX\n";
 }
 else
 {
  my @f=split '\t';
  my $mval=defined $sormap{$f[0]} ? $sormap{$f[0]} : "NA";
  print OUT1 "$mval\t$f[1]\t$f[2]\t$f[3]\t$f[4]\t$f[5]\n";
 }
}
close(INP1);
close(OUT1);


my $pullprofiles="y";
#now pull profiles for the required piids and poids as needed
my %ID_Info;
if($pullprofiles eq "y")
{

if($grp1ent eq "PI" || $grp2ent eq "PI")
{
 print "getting HCP info\n";
 &getHCPinfo;
 print "getting HCP typ\n";
 &getHCPtyp;
 print "getting HCP spec\n";
 &getHCPspec;
 print "getting HCP addr\n";
 &getHCPaddr;
 print "getting HCP phone fax\n";
 &getHCPphfx;
 print "getting HCP npi\n";
 &getHCPnpi;
}

if($grp1ent eq "PO" || $grp2ent eq "PO")
{
 print "getting HCO info\n";
 &getHCOinfo;
 print "getting HCO NPI\n";
 &getHCOnpi;
 print "getting HCO phone fax\n";
 &getHCOphfx;
}

}

#read the SAS results
if(-e "terrlinksrank.txt")
{
 open(INPTL,"terrlinksrank.txt");
 while(<INPTL>)
 {
  chomp;
  next if(m/^Link/);
  my @f=split '\t';
  $linkcntwrank{$f[0]}.=":$f[1]";
 }
 close(INPTL);
}
else
{
 print "cannot find SAS output file terrlinksrank.txt\n";
 exit;
}

#output info
open(OUT,">network.txt");
print OUT "HMS_".$grp1ent."ID1\t";
if($relational eq "n" || $relational eq "both")
{
 if($grp1ent eq "PI")
 {
  print OUT "FIRST_1\tMIDDLE_1\tLAST_1\tSUFFIX_1\tCRED_1\t";
  print OUT "PRACTITIONER_TYPE_1\tHMS_SPEC1_1\tHMS_SPEC2_1\tADDRESS1_1\t";
  print OUT "ADDRESS2_1\tCITY_1\tSTATE_1\tZIP_1\tZIP4_1\tCOUNTY_1\t";
  print OUT "PHONE1_1\tPHONE2_1\tFAX_1\tNPI_1\t";
 }
 elsif($grp1ent eq "PO")
 {
  print OUT "ORGNAME_1\tORG_TYPE_1\tADDRESS1_1\t";
  print OUT "ADDRESS2_1\tCITY_1\tSTATE_1\tZIP_1\tZIP4_1\tCOUNTY_1\t";
  print OUT "PHONE1_1\tPHONE2_1\tFAX_1\tORG_NPI_1\t";
 }
 if($ngr == 1)
 {
  print OUT "GRP1_VOLUME_NATL_RANK1\tGRP1_VOLUME_TERR_RANK1\t";
  print OUT "NATL_NUM_CONN_ENTITIES1\tTERR_NUM_CONN_ENTITIES1\t";
 }
 elsif($ngr == 2)
 {
  print OUT "GRP1_VOLUME_NATL_RANK\tGRP1_VOLUME_TERR_RANK\t";
  print OUT "NATL_NUM_CONN_GRP2_ENTITIES\tTERR_NUM_CONN_GRP2_ENTITIES\t";
 }
}
print OUT ($ngr == 2) ? "HMS_".$grp2ent."ID2\t" : "HMS_".$grp1ent."ID2\t";
if($relational eq "n" || $relational eq "both")
{
 my $secondidtype=($ngr==2) ? $grp2ent : $grp1ent;
 if($secondidtype eq "PI")
 {
  print OUT "FIRST_2\tMIDDLE_2\tLAST_2\tSUFFIX_2\tCRED_2\t";
  print OUT "PRACTITIONER_TYPE_2\tHMS_SPEC1_2\tHMS_SPEC2_2\tADDRESS1_2\t";
  print OUT "ADDRESS2_2\tCITY_2\tSTATE_2\tZIP_2\tZIP4_2\tCOUNTY_2\t";
  print OUT "PHONE1_2\tPHONE2_2\tFAX_2\tNPI_2\t";
 } 
 elsif($secondidtype eq "PO")
 {
  print OUT "ORGNAME_2\tORG_TYPE_2\tADDRESS1_2\t";
  print OUT "ADDRESS2_2\tCITY_2\tSTATE_2\tZIP_2\tZIP4_2\tCOUNTY_2\t";
  print OUT "PHONE1_2\tPHONE2_2\tFAX_2\tORG_NPI_2\t";
 }
 if($ngr == 1)
 {
  print OUT "GRP1_VOLUME_NATL_RANK2\tGRP1_VOLUME_TERR_RANK2\t";
  print OUT "NATL_NUM_CONN_ENTITIES2\tTERR_NUM_CONN_ENTITIES2\t";
 }
 elsif($ngr == 2)
 {
  print OUT "GRP2_VOLUME_NATL_RANK\tGRP2_VOLUME_TERR_RANK\t";
  print OUT "NATL_NUM_CONN_GRP1_ENTITIES\tTERR_NUM_CONN_GRP1_ENTITIES\t";
 }
}
print OUT "NATL_SOR_VALUE\tTERR_SOR_VALUE\tPCT1\tPCT2";
if($addcnts eq "Y")
{
 print OUT "\tSharedPatientCount\n";
}
else
{
 print OUT "\n";
}
my @order = sort {&linkcnt($b) <=> &linkcnt($a) } (keys %linkcntwrank);
my %idsinnetwork;
foreach my $l (@order)
{
 #skip link if either doc does not appear in nat rank
 #this means the id is in global network, not in global denom
 #this is due to them being inactive
 #skip link if the mapping starts with 0 for either rank
 next if($sormap{&linknatrank($l)} =~ m/^0/ 
   || $sormap{&linksterrrank($l)}  =~ m/^0/);
 my ($p1,$p2)=split(":",$l);
 #DEBUG
 #print "|$l|\t|$p1|\t|$p2|\n";
 next unless(defined $id2natrank{$p1} && defined $id2natrank{$p2});
 if($ngr == 1)
 {
  $idsinnetwork{$p1}{1}++;
  $idsinnetwork{$p2}{1}++;
 } 
 elsif($ngr == 2)
 {
  $idsinnetwork{$p1}{1}++;
  $idsinnetwork{$p2}{2}++;
 }
 #print STDERR "$p1\t$p2\n";
 #DEBUG
 #print "|$p1|\n";
 my $dstr1=($relational eq "n" || $relational eq "both") ? &pidinfo($p1) : $p1;
 print OUT "$dstr1\t";
 if($relational eq "n" || $relational eq "both")
 {
  if($ngr == 1)
  {
   print OUT $id2natrank{$p1}{B},"\t",$id2terrrank{$p1}{B},"\t";
   print OUT "$id2natneigh{$p1}{B}\t$id2terrneigh{$p1}{B}\t";
  }
  elsif($ngr == 2)
  {
   #print STDERR "|$p1|\t|$id2natrank{$p1}{1}|\t|$id2terrrank{$p1}{1}|\n";
   print OUT $id2natrank{$p1}{1},"\t",$id2terrrank{$p1}{1},"\t";
   print OUT "$id2natneigh{$p1}{1}\t$id2terrneigh{$p1}{1}\t";
  }
 }

 my $dstr2=($relational eq "n" || $relational eq "both") ? &pidinfo($p2) : $p2;
 print OUT "$dstr2\t";
 if($relational eq "n" || $relational eq "both")
 {
  if($ngr == 1)
  {
   print OUT $id2natrank{$p2}{B},"\t",$id2terrrank{$p2}{B},"\t";
   print OUT "$id2natneigh{$p2}{B}\t$id2terrneigh{$p2}{B}\t";
  }
  elsif($ngr == 2)
  {
   print OUT $id2natrank{$p2}{2},"\t",$id2terrrank{$p2}{2},"\t";
   print OUT "$id2natneigh{$p2}{2}\t$id2terrneigh{$p2}{2}\t";
  }
 }
 print OUT "$sormap{&linknatrank($l)}\t$sormap{&linksterrrank($l)}\t";

 #calc shr pct
 my ($pct1,$pct2);
 if($ngr==1)
 {
  $pct1=100*&linkcnt($l)/$id2shrptcnt{$p1};
  $pct2=100*&linkcnt($l)/$id2shrptcnt{$p2};
 }
 elsif($ngr==2)
 {
  #print STDERR "|$l|\t|$id2shrptcntout{$p1}|\t|$id2shrptcntin{$p2}|\t|&linkcnt($l)\n";
  $pct1=100*&linkcnt($l)/$id2shrptcntout{$p1};
  $pct2=100*&linkcnt($l)/$id2shrptcntin{$p2};
 }
 $pct1=sprintf("%.1f",$pct1);
 $pct2=sprintf("%.1f",$pct2);
 if($addcnts eq "Y")
 {
  print OUT "$pct1\t$pct2\t",&linkcnt($l),"\n";
 }
 else
 {
  print OUT "$pct1\t$pct2\n";
 }
}

#flip if 1 group analysis
if($ngr == 1)
{
 foreach my $l (@order)
 {
  #skip link if either doc does not appear in nat rank
  #this means the id is in global network, not in global denom
  #this is due to them being inactive
  #skip link if the mapping starts with 0 for either rank
   next if($sormap{&linknatrank($l)} =~ m/^0/ 
   || $sormap{&linksterrrank($l)}  =~ m/^0/);

  my ($p2,$p1)=split(":",$l);
  next unless(defined $id2natrank{$p1} && defined $id2natrank{$p2});
  #print STDERR "$p1\t$p2\n";
  my $dstr1=($relational eq "n" || $relational eq "both") ? &pidinfo($p1) : $p1;
  print OUT "$dstr1\t";
  if($relational eq "n" || $relational eq "both")
  {
   if($ngr == 1)
   {
    print OUT $id2natrank{$p1}{B},"\t",$id2terrrank{$p1}{B},"\t";
    print OUT "$id2natneigh{$p1}{B}\t$id2terrneigh{$p1}{B}\t"
   }
   elsif($ngr == 2)
   {
    print OUT $id2natrank{$p1}{1},"\t",$id2terrrank{$p1}{1},"\t";
    print OUT "$id2natneigh{$p1}{1}\t$id2terrneigh{$p1}{1}\t"
   }
  }
 
  my $dstr2=($relational eq "n" || $relational eq "both") ? &pidinfo($p2) : $p2;
  print OUT "$dstr2\t";
  if($relational eq "n" || $relational eq "both")
  {
   if($ngr == 1)
   {
    print OUT $id2natrank{$p2}{B},"\t",$id2terrrank{$p2}{B},"\t";
    print OUT "$id2natneigh{$p2}{B}\t$id2terrneigh{$p2}{B}\t"
   }
   elsif($ngr == 2)
   {
    print OUT $id2natrank{$p2}{2},"\t",$id2terrrank{$p2}{2},"\t";
    print OUT "$id2natneigh{$p2}{2}\t$id2terrneigh{$p2}{2}\t"
   }
  }
  print OUT "$sormap{&linknatrank($l)}\t$sormap{&linksterrrank($l)}\t";
 
  #calc shr pct
  my $pct1=100*&linkcnt($l)/$id2shrptcnt{$p1};
  my $pct2=100*&linkcnt($l)/$id2shrptcnt{$p2};
  $pct1=sprintf("%.1f",$pct1);
  $pct2=sprintf("%.1f",$pct2);
  if($addcnts eq "Y")
  {
   print OUT "$pct1\t$pct2\t",&linkcnt($l),"\n";
  }
  else
  {
   print OUT "$pct1\t$pct2\n";
  }
 }
}
close(OUT);

#undef order to free up mem for rest of code
@order=();

#if relational was set to both, network.txt saved above has full profiles
#rename it to network_full.txt and cut out the needed columns into network.txt
if($relational eq "both")
{
 system("mv network.txt network_full.txt");
 #need to do some work on the header to figure out which columns to cut
 #it depends on whether piid or poid combos are selected
 #because the amount of profile data is different
 my $str=`head -1 network_full.txt`;
 chomp($str);
 my @f=split("\t",$str);
 my @want;
 for(my $i=0;$i<=$#f;$i++)
 {
  if($f[$i] =~ m/HMS_P|NATL_SOR/)
  {
   push @want,$i+1;
  }
 }
 my $s2=join(",",@want);
 my $cmd="cut -f".$s2."- network_full.txt > network.txt";
 print "|$cmd|\n";
 system($cmd);

 #old below
 #system("cut -f1,25,49- network_full.txt > network.txt");
}

#if relational output format was requested, 
#output indiv and org profile tables depending on entity types
#with MF and denom and network size info
if($relational eq "y" || $relational eq "both")
{
 my ($hcpFH,$hcoFH);
 if($grp1ent eq "PI" || $grp2ent eq "PI")
 {
  open($hcpFH,">network_indiv_profiles.txt");
  print $hcpFH "HMS_PIID\tFIRST\tMIDDLE\tLAST\tSUFFIX\tCRED\t";
  print $hcpFH "PRACTITIONER_TYPE\tHMS_SPEC1\tHMS_SPEC2\tADDRESS1\t";
  print $hcpFH "ADDRESS2\tCITY\tSTATE\tZIP\tZIP4\tCOUNTY\t";
  print $hcpFH "PHONE1\tPHONE2\tFAX\tNPI\t";
 }
 if($grp1ent eq "PO" || $grp2ent eq "PO")
 {
  open($hcoFH,">network_org_profiles.txt");
  print $hcoFH "HMS_POID\tORGNAME\tORGTYPE\tADDRESS1\t";
  print $hcoFH "ADDRESS2\tCITY\tSTATE\tZIP\tZIP4\tCOUNTY\t";
  print $hcoFH "PHONE1\tPHONE2\tFAX\tNPI\t";
 }
 if($ngr == 1)
 {
  if($grp1ent eq "PI" || $grp2ent eq "PI")
  {
   print $hcpFH "GRP1_VOLUME_NATL_RANK\tGRP1_VOLUME_TERR_RANK\t";
   print $hcpFH "NATL_NUM_CONN_ENTITIES\tTERR_NUM_CONN_ENTITIES\n";
  }
  if($grp1ent eq "PO" || $grp2ent eq "PO")
  {
   print $hcoFH "GRP1_VOLUME_NATL_RANK\tGRP1_VOLUME_TERR_RANK\t";
   print $hcoFH "NATL_NUM_CONN_ENTITIES\tTERR_NUM_CONN_ENTITIES\n";
  }
 }
 elsif($ngr == 2)
 {
  if($grp1ent eq "PI" || $grp2ent eq "PI")
  {
   print $hcpFH "GRP1_VOLUME_NATL_RANK\tGRP1_VOLUME_TERR_RANK\t";
   print $hcpFH "NATL_NUM_CONN_GRP2_ENTITIES\tTERR_NUM_CONN_GRP2_ENTITIES\t";
   print $hcpFH "GRP2_VOLUME_NATL_RANK\tGRP2_VOLUME_TERR_RANK\t";
   print $hcpFH "NATL_NUM_CONN_GRP1_ENTITIES\tTERR_NUM_CONN_GRP1_ENTITIES\n";
  }
  if($grp1ent eq "PO" || $grp2ent eq "PO")
  {
   print $hcoFH "GRP1_VOLUME_NATL_RANK\tGRP1_VOLUME_TERR_RANK\t";
   print $hcoFH "NATL_NUM_CONN_GRP2_ENTITIES\tTERR_NUM_CONN_GRP2_ENTITIES\t";
   print $hcoFH "GRP2_VOLUME_NATL_RANK\tGRP2_VOLUME_TERR_RANK\t";
   print $hcoFH "NATL_NUM_CONN_GRP1_ENTITIES\tTERR_NUM_CONN_GRP1_ENTITIES\n";
  }
 }
 
 foreach my $id (keys %idsinnetwork)
 {
  my $fh = ($id =~ m/^PI/) ? $hcpFH : $hcoFH;
  print $fh &pidinfo($id),"\t";
  if($ngr == 1)
  {
   print $fh $id2natrank{$id}{B},"\t",$id2terrrank{$id}{B},"\t";
   print $fh "$id2natneigh{$id}{B}\t$id2terrneigh{$id}{B}\n";
  }
  elsif($ngr == 2)
  {
   my @v1;
   push @v1,defined $id2natrank{$id}{1} ? $id2natrank{$id}{1} : "";
   push @v1,defined $id2terrrank{$id}{1} ? $id2terrrank{$id}{1} : "";
   push @v1,defined $id2natneigh{$id}{1} ? $id2natneigh{$id}{1} : "";
   push @v1,defined $id2terrneigh{$id}{1} ? $id2terrneigh{$id}{1} : "";
   my $str1=join("\t",@v1);
   print $fh "$str1\t";
   my @v2;
   push @v2,defined $id2natrank{$id}{2} ? $id2natrank{$id}{2} : "";
   push @v2,defined $id2terrrank{$id}{2} ? $id2terrrank{$id}{2} : "";
   push @v2,defined $id2natneigh{$id}{2} ? $id2natneigh{$id}{2} : "";
   push @v2,defined $id2terrneigh{$id}{2} ? $id2terrneigh{$id}{2} : "";
   my $str2=join("\t",@v2);
   print $fh "$str2\n";
  }
 }
 close($hcpFH) if($grp1ent eq "PI" || $grp2ent eq "PI");
 close($hcoFH) if($grp1ent eq "PO" || $grp2ent eq "PO");
}

#undef the big hash to avoid memory problems in rest of script
%linkcntwrank=();

#output the filter files with terr rank attached
#output only for those ids in the network
# i.e. if ids are only in relationships that are dropped due to SOR mapping 0
#, dont include them in the filter file
#new logic: 9.30.2013
#if no sor values start with zero, then force all ids with a terr rank into
# this file, including ones that have no connections at all
my $grp1terrheader;
if($grp1decilecol ne "")
{
 $grp1terrheader=$grp1decilecol;
 $grp1terrheader=~s/NATL/TERR/;
}
else
{
 $grp1terrheader="TERR_RANK";
}
open(OUT1,">$grp1filtfile_o");
print OUT1 defined $grp1universe{$grp1filtkey}{Info} ? 
 $grp1universe{$grp1filtkey}{Info} : $wantidgrp1{$grp1filtkey}{Info},
  "\t$grp1terrheader\n";
my %combinedidsgrp1;
if($have0sormap eq "y")
{
 if($ngr == 1)
 {
  %combinedidsgrp1 = %idsinnetwork;
 }
 elsif($ngr == 2)
 {
  foreach my $id (keys %idsinnetwork)
  {
   $combinedidsgrp1{$id}++ if(defined $idsinnetwork{$id}{1});
  }
 }
}
else
{
 #combine the input ids and the network ids together
 foreach my $id (keys %wantidgrp1)
 {
  $combinedidsgrp1{$id}++;
 }
 foreach my $id (keys %idsinnetwork)
 {
  if($ngr == 1)
  {
   $combinedidsgrp1{$id}++;
  }
  elsif($ngr == 2)
  {
   $combinedidsgrp1{$id}++ if(defined $idsinnetwork{$id}{1});
  }
 }
}
foreach my $id (keys %combinedidsgrp1)
{
 #commented out below, because it forces the id to be in the network
 #and doesnt allow filter list ids not in network to enter this file
 #if(defined $id2cnt{$id}{$k})
 #{
  if($have0sormap eq "y")
  {
   next unless(defined $idsinnetwork{$id}{1});
  }
  if( ( defined $grp1universe{$id}{Info} || defined $wantidgrp1{$id}{Info})
          && defined $id2terrrank{$id}{$k})
  {
   print OUT1 defined $grp1universe{$id}{Info} ? $grp1universe{$id}{Info}
         : $wantidgrp1{$id}{Info},"\t$id2terrrank{$id}{$k}\n";
  }
 #}
}
close(OUT1);


my %combinedidsgrp2;
if($ngr == 2)
{
 my $grp2terrheader;
 if($grp2decilecol ne "")
 {
  $grp2terrheader=$grp2decilecol;
  $grp2terrheader=~s/NATL/TERR/;
 }
 else
 {
  $grp2terrheader="TERR_RANK";
 }
 open(OUT2,">$grp2filtfile_o");
 print OUT2 defined $grp2universe{$grp2filtkey}{Info} ? 
 $grp2universe{$grp2filtkey}{Info} : $wantidgrp2{$grp2filtkey}{Info},
  "\t$grp2terrheader\n";
 if($have0sormap eq "y")
 {
  foreach my $id (keys %idsinnetwork)
  {
   $combinedidsgrp2{$id}++ if(defined $idsinnetwork{$id}{2});
  }
 }
 else
 {
  #combine the input ids and the network ids together
  foreach my $id (keys %wantidgrp2)
  {
   $combinedidsgrp2{$id}++;
  }
  foreach my $id (keys %idsinnetwork)
  {
   $combinedidsgrp2{$id}++ if(defined $idsinnetwork{$id}{2});
  }
 }

 foreach my $id (keys %combinedidsgrp2)
 {
  #if(defined $id2cnt{$id}{2})
  #{
   if($have0sormap eq "y")
   {
    next unless(defined $idsinnetwork{$id}{2});
   }
   if( (defined $grp2universe{$id}{Info} || defined $wantidgrp2{$id}{Info})
          && defined $id2terrrank{$id}{2})
   {
    print OUT2 defined $grp2universe{$id}{Info} ? $grp2universe{$id}{Info} 
          : $wantidgrp2{$id}{Info} ,"\t$id2terrrank{$id}{2}\n";
   }
  }
 #}
}
close(OUT2);


#now output a filtered pxdx affiliations tab, if requested
#this portion is for the grp1 pxdx, have separate one for the grp2 pxdx
my %wantsecondkey;
my $filtcol=-1;
my $secondcol=-1;
if($grp1affilsfile ne "")
{
 open(INP,$grp1affilsfile) or die "cant open $grp1affilsfile\n";
 open(OUT,">affils_grp1_filtered.tab");
 #search for location of the filter key and the 2nd key
 my $line=0;
 while(<INP>)
 {
  chomp;
  $line++;
  my @f=split '\t';
  if($line==1)
  {
   print OUT "$_\n";
   #figure out the filter key and 2nd key columns
   for my $i (0 .. $#f)
   {
    $filtcol=$i if($f[$i] =~ m/$grp1filtkey/i);
    $secondcol=$i if($f[$i] =~ m/$grp1secondkey/i);
   }
   print "in Grp1 affils file, filter column = |$filtcol|\n";
   print "in Grp1 affils file, second column = |$secondcol|\n";
  }
  else
  {
   #if(defined $idsinnetwork{$f[$filtcol]}{1})
   #if(defined $wantidgrp1{$f[$filtcol]})
   if(defined $combinedidsgrp1{$f[$filtcol]})
   {
    print OUT "$_\n";
    $wantsecondkey{$f[$secondcol]}++;
   }
  }
 }
 close(INP);
 close(OUT);

 #now do the filtering on the milestones version
 my $af_milestones=$grp1affilsfile;
 $af_milestones=~s/QA/milestones/g;
 open(INP,$af_milestones) or die "cant open $af_milestones\n";
 open(OUT,">affils_grp1_fordelivery.tab");
 while(<INP>)
 {
  chomp;
  my @f=split '\t';
  #search for filter and second key locations
  if($.==1)
  {
   for my $i (0 .. $#f)
   {
    $filtcol=$i if($f[$i] =~ m/$grp1filtkey/i);
    $secondcol=$i if($f[$i] =~ m/$grp1secondkey/i);
   }
   print OUT "$_\n";
  }
  else
  {
   if(defined $combinedidsgrp1{$f[$filtcol]})
   {
    print OUT "$_\n";
   }
  }
 }
 close(INP);
 close(OUT);
}


#now output a filtered pxdx affiliations tab, if requested
#this portion is for the grp2 pxdx
my %wantsecondkey_grp2;
if($grp2affilsfile ne "")
{
 open(INP,$grp2affilsfile) or die "cant open $grp2affilsfile\n";
 open(OUT,">affils_grp2_filtered.tab");
 my $line=0;
 while(<INP>)
 {
  chomp;
  $line++;
  my @f=split '\t';
  if($line==1)
  {
   print OUT "$_\n";
   #figure out the filter key and 2nd key columns
   for my $i (0 .. $#f)
   {
    $filtcol=$i if($f[$i] =~ m/$grp2filtkey/i);
    $secondcol=$i if($f[$i] =~ m/$grp2secondkey/i);
   }
   print "in Grp2 affils file, filter column = |$filtcol|\n";
   print "in Grp2 affils file, second column = |$secondcol|\n";
  }
  else
  {
   if(defined $combinedidsgrp2{$f[$filtcol]})
   {
    print OUT "$_\n";
    $wantsecondkey_grp2{$f[$secondcol]}++;
   }
  }
 }
 close(INP);
 close(OUT);

 #now do the filtering on the milestones version
 my $af_grp2_milestones=$grp2affilsfile;
 $af_grp2_milestones=~s/QA/milestones/g;
 open(INP,$af_grp2_milestones) or die "cant open $af_grp2_milestones\n";
 open(OUT,">affils_grp2_fordelivery.tab");
 while(<INP>)
 {
  chomp;
  my @f=split '\t';
  if($.==1)
  {
   #figure out the filter key and 2nd key columns
   for my $i (0 .. $#f)
   {
    $filtcol=$i if($f[$i] =~ m/$grp2filtkey/i);
    $secondcol=$i if($f[$i] =~ m/$grp2secondkey/i);
   }
   print OUT "$_\n";
  }
  else
  {
   if(defined $combinedidsgrp2{$f[$filtcol]})
   {
    print OUT "$_\n";
   }
  }
 }
 close(INP);
 close(OUT);
}

#now ouput a filtered second file if requested
#this is for the grp1 volumetrics data, have separate section for the grp2
if($grp1secondfile ne "")
{
 #if secondfile count column is specified, grab count to calc terr rank
 my (%id_info,%id_count,$terr_header);
 $terr_header="TERR_RANK";
 print "number of Grp1 second file ids to include = ",
              scalar(keys %wantsecondkey),"\n";
 open(INP,$grp1secondfile) or die "cant open $grp1secondfile\n";
 my %m;
 while(<INP>)
 {
  chomp;
  my @f=split '\t';
  if($. == 1)
  {
   #grab the header
   foreach my $i (0 .. $#f)
   {
    $m{$f[$i]}=$i;
   }
   #make sure id column exists
   unless(defined $m{$grp1secondkey})
   {
    print "|$grp1secondkey| column does not exist in file |$grp1secondfile|\n";
   }
   #make sure count column exists
   if($grp1secondfile_countcol ne "")
   {
    unless(defined $m{$grp1secondfile_countcol})
    {
     print "col |$grp1secondfile_countcol| does not exist in |$grp1secondfile|\n";
     print "will not do terr-level secondfile count re-deciling\n";
    }
    else
    {
     #count col exists, use it to figure out the name of the terr rank column
     my @t=split("_TOTAL_",$grp1secondfile_countcol);
     $terr_header=$t[0]."_TERR_RANK";
    }
   }
   $id_info{$grp1secondkey}=$_;
  }
  else
  {
   if(defined $wantsecondkey{$f[$m{$grp1secondkey}]})
   {
    $id_info{$f[$m{$grp1secondkey}]}=$_;
    $id_count{$f[$m{$grp1secondkey}]}=$f[$m{$grp1secondfile_countcol}] if(defined $m{$grp1secondfile_countcol});
   }
  }
 }
 close(INP);

 my %id2terrrank;
 #have counts, do the terr deciling
 if(scalar (keys %id_count) > 0)
 {
  open(OUTO,">terrcount.txt");
  print OUTO "$grp1secondkey\tCount\n"; 
  foreach my $id (keys %id_count)
  {
   print OUTO "$id\t$id_count{$id}\n";
  }
  close(OUTO);

  system("perl $deciledir/decile --in terrcount.txt --out terrrank.txt --group NONE --atom $grp1secondkey --score Count --ncile $dbins");
  if(-e "decileranksoutput.txt")
  {
   system("rm decileranksoutput.txt");
  }
  system("ln -s terrrank.txt decileranksoutput.txt");
  system("rm calcdenommedianmean.log") if(-e "calcdenommedianmean.log");
  system("sas -noterminal $codedir/calcdenommedianmean.sas");
  system("mv medmean.txt secondterrranksummary.txt");

  #read the terr deciles
  open(INPO,"terrrank.txt") or die "no second terr rank file terrrank.txt exists\n";
  while(<INPO>)
  {
   chomp;
   next if(m/$grp1secondkey/);
   my @f=split '\t';
   $id2terrrank{$f[1]}=$f[4];
  }
  close(INPO);
 }

 #now output filtered second file with terr rank

 open(OUT,">$grp1secondfile_o");
 print OUT "$id_info{$grp1secondkey}";
 print OUT scalar(keys %id2terrrank) > 0 ? "\t$terr_header\n" : "\n";
 foreach my $id (keys %id_info)
 {
  next if($id eq "$grp1secondkey");
  print OUT $id_info{$id};
  print OUT scalar(keys %id2terrrank) > 0 ? "\t$id2terrrank{$id}\n" : "\n";
 }
 close(OUT);
}

#now ouput a filtered second file if requested for the grp2 volumetrics
if($grp2secondfile ne "")
{
 #if secondfile count column is specified, grab count to calc terr rank
 my (%id_info,%id_count,$terr_header);
 $terr_header="TERR_RANK";
 print "number of Grp2 second ids to include = ",scalar(keys %wantsecondkey_grp2),"\n";
 open(INP,$grp2secondfile) or die "cant open $grp2secondfile\n";
 my %m;
 while(<INP>)
 {
  chomp;
  my @f=split '\t';
  if($. == 1)
  {
   #grab the header
   foreach my $i (0 .. $#f)
   {
    $m{$f[$i]}=$i;
   }
   #make sure id column exists
   unless(defined $m{$grp2secondkey})
   {
    print "$grp2secondkey column does not exist in file |$grp2secondfile|\n";
   }
   #make sure count column exists for the grp2 file
   if($grp2secondfile_countcol ne "")
   {
    unless(defined $m{$grp2secondfile_countcol})
    {
     print "col |$grp2secondfile_countcol| does not exist in |$grp2secondfile|\n";
     print "will not do terr-level secondfile count re-deciling\n";
    }
    else
    {
     #count col exists, use it to figure out the name of the terr rank column
     my @t=split("_TOTAL_",$grp2secondfile_countcol);
     $terr_header=$t[0]."_TERR_RANK";
    }
   }
   $id_info{$grp2secondkey}=$_;
  }
  else
  {
   if(defined $wantsecondkey_grp2{$f[$m{$grp2secondkey}]})
   {
    $id_info{$f[$m{$grp2secondkey}]}=$_;
    $id_count{$f[$m{$grp2secondkey}]}=$f[$m{$grp2secondfile_countcol}] if(defined $m{$grp2secondfile_countcol});
   }
  }
 }
 close(INP);

 my %id2terrrank;
 #have counts, do the terr deciling
 if(scalar (keys %id_count) > 0)
 {
  open(OUTO,">terrcount_grp2.txt");
  print OUTO "$grp2secondkey\tCount\n"; 
  foreach my $id (keys %id_count)
  {
   print OUTO "$id\t$id_count{$id}\n";
  }
  close(OUTO);

  system("perl $deciledir/decile --in terrcount_grp2.txt --out terrrank_grp2.txt --group NONE --atom $grp2secondkey --score Count --ncile $dbins");
  if(-e "decileranksoutput.txt")
  {
   system("rm decileranksoutput.txt");
  }
  system("ln -s terrrank_grp2.txt decileranksoutput.txt");
  system("rm calcdenommedianmean.log") if(-e "calcdenommedianmean.log");
  system("sas -noterminal $codedir/calcdenommedianmean.sas");
  system("mv medmean.txt secondterrranksummary_grp2.txt");

  #read the terr deciles
  open(INPO,"terrrank_grp2.txt") or die "no second terr rank file terrrank_grp2.txt exists\n";
  while(<INPO>)
  {
   chomp;
   next if(m/$grp2secondkey/);
   my @f=split '\t';
   $id2terrrank{$f[1]}=$f[4];
  }
  close(INPO);
 }

 #now output filtered org file with terr rank

 open(OUT,">$grp2secondfile_o");
 print OUT "$id_info{$grp2secondkey}";
 print OUT scalar(keys %id2terrrank) > 0 ? "\t$terr_header\n" : "\n";
 foreach my $id (keys %id_info)
 {
  next if($id eq "$grp2secondkey");
  print OUT $id_info{$id};
  print OUT scalar(keys %id2terrrank) > 0 ? "\t$id2terrrank{$id}\n" : "\n";
 }
 close(OUT);
}

#8.28.2014
#decision to do star is more complex than just checking for decile col
#like it used to be
my $dostar="n";
$dostar="y" if($grp1affilsfile =~ m/QA/);
$dostar="y" if($grp2affilsfile =~ m/QA/);
$dostar="y" if($grp1secondfile =~ m/QA/);
$dostar="y" if($grp2secondfile =~ m/QA/);
$dostar="y" if($grp1decilecol ne "");
$dostar="y" if($grp2decilecol ne "");
#call the script to star out < 11 and produce _fordelivery versions of the
#if no grp1decile col, assume that things dont need to be starred
#if user is providing full Pxdx files, but not using the counts,
#they must use the milestones files, not the QA files
#if($grp1decilecol ne "" || $grp2decilecol ne "")
print "dostar value is = |$dostar|\n";
#undef ID_Info to get last system command to run
%ID_Info=();
if($dostar eq "y")
{
 system("R CMD BATCH  --vanilla $codedir/star.R");
}

system("touch done.txt");
system("perl /vol/datadev/Statistics/Projects/NewProjWorkFlow/Dev/sendemail.pl InfluenceNetworkFilter");




sub getHCPnpi
{
 my $sql1=qq|select 
  HMS_PIID,NPI from
 ddb_$vint.m_npi|;

 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $doc=$ref->{HMS_PIID};
  next unless(defined $wantid{$doc});
  $ID_Info{$doc}{NPI}=$ref->{NPI};
 }
 $sth1->finish;
 return;
}


sub getHCPinfo
{
 my $sql1=qq|select 
  a.HMS_PIID,a.FIRST_NAME,a.MIDDLE_NAME1,a.LAST_NAME,a.NAME_SUFFIX,
  a.CREDENTIAL1  from
 ddb_$vint.m_practitioner a |;

 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $doc=$ref->{HMS_PIID};
  next unless(defined $wantid{$doc});
  $ID_Info{$doc}{FN}=$ref->{FIRST_NAME};
  $ID_Info{$doc}{MN}=$ref->{MIDDLE_NAME1};
  $ID_Info{$doc}{LN}=$ref->{LAST_NAME};
  $ID_Info{$doc}{SFFX}=$ref->{NAME_SUFFIX};
  $ID_Info{$doc}{CR}=$ref->{CREDENTIAL1};
 }
 $sth1->finish;
 return;
}

sub getHCPtyp
{
 my $sql1=qq|select HMS_PIID,PRACTITIONER_TYPE_DESCRIPTION
      from ddb_$vint.m_practitioner_type|;

 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $doc=$ref->{HMS_PIID};
  next unless(defined $wantid{$doc});
  $ID_Info{$doc}{PRTYP}=$ref->{PRACTITIONER_TYPE_DESCRIPTION};
 }
 $sth1->finish;
 return;
}

sub getHCPspec
{
 my $sql1=qq|select HMS_PIID,ABBREV_SPECIALTY_DESCRIPTION,RANK
      from ddb_$vint.m_abbreviated_specialty where rank < 3|;
 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $doc=$ref->{HMS_PIID};
  next unless(defined $wantid{$doc});
  if($ref->{RANK} == 1)
  {
   $ID_Info{$doc}{SP1}=$ref->{ABBREV_SPECIALTY_DESCRIPTION};
  }
  else
  {
   $ID_Info{$doc}{SP2}=$ref->{ABBREV_SPECIALTY_DESCRIPTION};
  }
 }
 $sth1->finish;
 return;
}

sub getHCPaddr
{
 my $sql1=qq|
  select d.HMS_PIID,c.address_line1,c.address_line2,c.city_name,
   c.state_code,c.address_zip5,c.address_zip4,c.fips5_code
  from
    ddb_|.$vint.qq|.m_address c,
    ddb_|.$vint.qq|.m_practitioner_address d
   where
    c.address_key = d.address_key and
     d.rank=1
    |;

 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $doc=$ref->{HMS_PIID};
  next unless(defined $wantid{$doc});
  $ID_Info{$doc}{A1}=$ref->{ADDRESS_LINE1};
  $ID_Info{$doc}{A2}=$ref->{ADDRESS_LINE2};
  $ID_Info{$doc}{CITY}=$ref->{CITY_NAME};
  $ID_Info{$doc}{ST}=$ref->{STATE_CODE};
  $ID_Info{$doc}{ZIP}=$ref->{ADDRESS_ZIP5};
  $ID_Info{$doc}{ZIP4}=$ref->{ADDRESS_ZIP4};
  $ID_Info{$doc}{FIPS}=$ref->{FIPS5_CODE};
 }
 $sth1->finish;
 return;

}

sub getHCPphfx
{
 my $sql1=qq|
  select d.HMS_PIID,b.phone_number,b.rank
  from
    ddb_|.$vint.qq|.m_address c,
    ddb_|.$vint.qq|.m_practitioner_address d,
    ddb_|.$vint.qq|.m_address_phone b
   where
    c.address_key = d.address_key and
     d.rank=1 and d.hms_piid=b.hms_piid and c.address_key=b.address_key
   and b.rank < 3
    |;

 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $doc=$ref->{HMS_PIID};
  next unless(defined $wantid{$doc});
  if($ref->{RANK} == 1)
  {
   $ID_Info{$doc}{PH1}=$ref->{PHONE_NUMBER};
  }
  else
  {
   $ID_Info{$doc}{PH2}=$ref->{PHONE_NUMBER};
  }

 }
 $sth1->finish();

 my $sql2=qq|
  select d.HMS_PIID,b.fax_number,b.rank
  from
    ddb_|.$vint.qq|.m_address c,
    ddb_|.$vint.qq|.m_practitioner_address d,
    ddb_|.$vint.qq|.m_address_fax b
   where
    c.address_key = d.address_key and
     d.rank=1 and d.hms_piid=b.hms_piid and c.address_key=b.address_key
   and b.rank = 1
    |;

 print "$sql2\n";

 my $sth2=$dbhA->prepare($sql2) or die "could not prepare stmt ".$dbhA->errstr;
 $sth2->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth2->fetchrow_hashref())
 {
  my $doc=$ref->{HMS_PIID};
  next unless(defined $wantid{$doc});
  $ID_Info{$doc}{FX1}=$ref->{FAX_NUMBER};
 }
 $sth1->finish();
 return;
}

sub pidinfo
{
 my $id=shift;

 my $str="";
 if($id =~ m/^PI/)
 {
  my $FN = defined  $ID_Info{$id}{FN} ? $ID_Info{$id}{FN} : "";
  my $MN = defined $ID_Info{$id}{MN} ? $ID_Info{$id}{MN} : "";
  my $LN = defined $ID_Info{$id}{LN} ? $ID_Info{$id}{LN} : "";
  my $SFFX = defined $ID_Info{$id}{SFFX} ? $ID_Info{$id}{SFFX} : "";
  my $CRED = defined $ID_Info{$id}{CR} ? $ID_Info{$id}{CR} : "";
  my $PRTYP = defined $ID_Info{$id}{PRTYP} ? $ID_Info{$id}{PRTYP} : "";
  my $SP1 = defined $ID_Info{$id}{SP1} ? $ID_Info{$id}{SP1} : "";
  my $SP2 = defined $ID_Info{$id}{SP2} ? $ID_Info{$id}{SP2} : "";
  my $A1 = defined $ID_Info{$id}{A1} ? $ID_Info{$id}{A1} : "";
  my $A2 = defined $ID_Info{$id}{A2} ? $ID_Info{$id}{A2} : "";
  my $CITY = defined $ID_Info{$id}{CITY} ? $ID_Info{$id}{CITY} : "";
  my $ST = defined $ID_Info{$id}{ST} ? $ID_Info{$id}{ST} : "";
  my $ZIP = defined $ID_Info{$id}{ZIP} ? $ID_Info{$id}{ZIP} : "";
  my $ZIP4 = defined $ID_Info{$id}{ZIP4} ? $ID_Info{$id}{ZIP4} : "";
  my $FIPS = defined $ID_Info{$id}{FIPS} ? $ID_Info{$id}{FIPS} : "";
  my $cnty=defined $fip2cnty{$FIPS} ? $fip2cnty{$FIPS} : $FIPS;
  my $PH1 = defined $ID_Info{$id}{PH1} ? $ID_Info{$id}{PH1} : "";
  my $PH2 = defined $ID_Info{$id}{PH2} ? $ID_Info{$id}{PH2} : "";
  my $FX1 = defined $ID_Info{$id}{FX1} ? $ID_Info{$id}{FX1} : "";
  my $NPI = defined $ID_Info{$id}{NPI} ? $ID_Info{$id}{NPI} : "";
  
  $str=join("\t",($id,$FN,$MN,$LN,$SFFX,$CRED,$PRTYP,$SP1,$SP2,$A1,$A2,$CITY,$ST,$ZIP,$ZIP4,$cnty,$PH1,$PH2,$FX1,$NPI));
 }
 elsif($id =~ m/^PO/)
 {
  my $ORGNM = defined  $ID_Info{$id}{ORGNM} ? $ID_Info{$id}{ORGNM} : "";
  my $ORGTYP = defined $ID_Info{$id}{ORGTYP} ? $ID_Info{$id}{ORGTYP} : "";
  my $A1 = defined $ID_Info{$id}{A1} ? $ID_Info{$id}{A1} : "";
  my $A2 = defined $ID_Info{$id}{A2} ? $ID_Info{$id}{A2} : "";
  my $CITY = defined $ID_Info{$id}{CITY} ? $ID_Info{$id}{CITY} : "";
  my $ST = defined $ID_Info{$id}{ST} ? $ID_Info{$id}{ST} : "";
  my $ZIP = defined $ID_Info{$id}{ZIP} ? $ID_Info{$id}{ZIP} : "";
  my $ZIP4 = defined $ID_Info{$id}{ZIP4} ? $ID_Info{$id}{ZIP4} : "";
  my $FIPS = defined $ID_Info{$id}{FIPS} ? $ID_Info{$id}{FIPS} : "";
  my $cnty=defined $fip2cnty{$FIPS} ? $fip2cnty{$FIPS} : $FIPS;
  my $PH1 = defined $ID_Info{$id}{PH1} ? $ID_Info{$id}{PH1} : "";
  my $PH2 = defined $ID_Info{$id}{PH2} ? $ID_Info{$id}{PH2} : "";
  my $FX1 = defined $ID_Info{$id}{FX1} ? $ID_Info{$id}{FX1} : "";
  my $ONPI = defined $ID_Info{$id}{ONPI} ? $ID_Info{$id}{ONPI} : "";

  $str=join("\t",($id,$ORGNM,$ORGTYP,$A1,$A2,$CITY,$ST,$ZIP,$ZIP4,$cnty,$PH1,$PH2,$FX1,$ONPI));
 }
 return $str;
}

sub readidfile
{
 my ($href,$filename,$decilecol,$countcol,$ent)=@_;
 open(INP,$filename) or die "cant open $filename\n";
 my %m;
 my $line=0;
 my $idcol="HMS_".$ent."ID";
 while(<INP>)
 {
  chomp;
  s/\015//g;
  my @f=split '\t';
  $line++;
  if($line == 1)
  {
   #grab the header
   foreach my $i (0 .. $#f)
   {
    $m{$f[$i]}=$i;
   }
   #make sure id column exists
   unless(defined $m{$idcol})
   {
    print "|$idcol| column does not exist in file |$filename|\n";
    unless(defined $m{'HMS_ID'})
    {
     print "|HMS_ID| column does not exist either in file |$filename|\n";
     print "will not use this file to filter\n";
     return;
    }
    else
    {
     $idcol="HMS_ID";
     print "using |HMS_ID| column instead in file |$filename|\n";
    }
   }
   #make sure decile column exists 
   if($decilecol ne "")
   {
    unless(defined $m{$decilecol})
    {
     print "Decile column |$decilecol| does not exist in file |$filename|\n";
     print "will not use that decile\n";
     $decilecol="";
    }
   }
   #make sure count column exists
   if($countcol ne "")
   {
    unless(defined $m{$countcol})
    {
     print "Count column |$countcol| does not exist in file |$filename|\n";
     print "will not use that count\n";
     $countcol="";
    }
   }

   $href->{$f[$m{$idcol}]}->{Info}=$_;
  }
  else
  {
   $href->{$f[$m{$idcol}]}->{Info}=$_;
   if($decilecol eq "" || $countcol eq "")
   {
    $href->{$f[$m{$idcol}]}->{Rank}=0;
    $href->{$f[$m{$idcol}]}->{Count}=0;
   }
   else
   {
    $href->{$f[$m{$idcol}]}->{Rank}=$f[$m{$decilecol}];
    $href->{$f[$m{$idcol}]}->{Count}=$f[$m{$countcol}];
   }
  }
 }
 close(INP);
}

#sub to figure out which count to use in the terr ranking
#and return an undef scalar if this id should not be in the terr ranking
sub getcount
{
 my ($id,$netcnt,$grp)=@_;
 my $c;
 $c=$netcnt if($netcnt ne "");
 
 if($grp == 1)
 {
  if($grp1decilecol ne "")
  {
   $c=defined $grp1universe{$id}{Count} ? $grp1universe{$id}{Count} : 
      $wantidgrp1{$id}{Count};
  }
 }
 elsif($grp == 2)
 {
  if($grp2decilecol ne "")
  {
   $c=defined $grp2universe{$id}{Count} ? $grp2universe{$id}{Count} : 
      $wantidgrp2{$id}{Count};
  }
 }

 return $c;
}

sub getHCOinfo
{

 my $sql1=qq|
 select 
  a.hms_poid,a.org_name, c.address_line1, c.address_line2, c.city_name,
  c.state_code, c.address_zip5, c.address_zip4, c.fips5_code,
  d.org_type_description
 from 
  ddb_|.$vint.qq|.m_organization a
  left join ddb_|.$vint.qq|.m_organization_address b on a.hms_poid=b.hms_poid
  left join ddb_|.$vint.qq|.m_address_org c 
                on b.org_address_key=c.org_address_key
  left join ddb_|.$vint.qq|.m_org_type d 
    on a.hms_poid = d.hms_poid and d.org_type_code like '1%' and d.rank=1
 where
   b.rank=1
 |;

 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $org=$ref->{HMS_POID};
  next unless(defined $wantid{$org});
  $ID_Info{$org}{ORGNM}=$ref->{ORG_NAME};
  $ID_Info{$org}{A1}=$ref->{ADDRESS_LINE1};
  $ID_Info{$org}{A2}=$ref->{ADDRESS_LINE2};
  $ID_Info{$org}{CITY}=$ref->{CITY_NAME};
  $ID_Info{$org}{ST}=$ref->{STATE_CODE};
  $ID_Info{$org}{ZIP}=$ref->{ADDRESS_ZIP5};
  $ID_Info{$org}{ZIP4}=$ref->{ADDRESS_ZIP4};
  $ID_Info{$org}{FIPS}=$ref->{FIPS5_CODE};
  $ID_Info{$org}{ORGTYP}=$ref->{ORG_TYPE_DESCRIPTION};
 }
 return;
}

sub getHCOnpi
{
 my $sql1=qq|select HMS_POID,ORG_NPI from
 ddb_$vint.m_org_npi where rank=1|;

 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $org=$ref->{HMS_POID};
  next unless(defined $wantid{$org});
  $ID_Info{$org}{ONPI}=$ref->{ORG_NPI};
 }
 $sth1->finish;
 return;
}


sub getHCOphfx
{
 my $sql1=qq|
  select c.HMS_POID,b.org_phone_number,b.rank
  from
    ddb_|.$vint.qq|.m_organization_address c,
    ddb_|.$vint.qq|.m_org_address_phone b
   where
    c.org_address_key = b.org_address_key and
     c.rank=1 and b.rank < 3
    |;

 print "$sql1\n";

 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $org=$ref->{HMS_POID};
  next unless(defined $wantid{$org});
  if($ref->{RANK} == 1)
  {
   $ID_Info{$org}{PH1}=$ref->{ORG_PHONE_NUMBER};
  }
  else
  {
   $ID_Info{$org}{PH2}=$ref->{ORG_PHONE_NUMBER};
  }

 }

 my $sql2=qq|
  select c.HMS_POID,b.org_fax_number,b.rank
  from
    ddb_|.$vint.qq|.m_organization_address c,
    ddb_|.$vint.qq|.m_org_address_fax b
   where
    c.org_address_key = b.org_address_key and
     c.rank=1 and b.rank = 1
    |;

 print "$sql2\n";

 my $sth2=$dbhA->prepare($sql2) or die "could not prepare stmt ".$dbhA->errstr;
 $sth2->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth2->fetchrow_hashref())
 {
  my $org=$ref->{HMS_POID};
  next unless(defined $wantid{$org});
  $ID_Info{$org}{FX1}=$ref->{ORG_FAX_NUMBER};
 }
 $sth1->finish();
 return;
}


sub linkcnt
{
 my $l=$_[0];
 return (split(":",$linkcntwrank{$l}))[0];
}

sub linknatrank
{
 my $l=$_[0];
 return (split(":",$linkcntwrank{$l}))[1];
}

sub linksterrrank
{
 my $l=$_[0];
 return (split(":",$linkcntwrank{$l}))[2];
}

