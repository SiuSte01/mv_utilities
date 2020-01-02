#!/usr/bin/perl -w
use strict;
use DBI;

#do diag PostAcuteCare projections

#read the input.txt file from 1 level up and get the input parameters
my ($counttype,$vint,$codetype,$bucket,$username,$password,$instance);
my ($aggregation_table,$fxfiles,$aggregation_id,%settings);
open my $lofh, ">", "pacProjStdErr";
open(INP,"input.txt") or die "cant open input.txt\n";
while(<INP>)
{
 if($. > 1)
 {
  chomp;
  s/\015//g;
  my @f=split '\t';
  $vint=$f[1] if($f[0] eq "VINTAGE");
  $counttype=$f[1] if($f[0] eq "COUNTTYPE");
  $bucket="'".$f[1]."'" if($f[0] eq "BUCKET");
  $username=$f[1] if($f[0] eq "USERNAME");
  $password=$f[1] if($f[0] eq "PASSWORD");
  $instance=$f[1] if($f[0] eq "INSTANCE");
  $aggregation_table=$f[1] if($f[0] eq "AGGREGATION_TABLE");
  $aggregation_id=$f[1] if($f[0] eq "AGGREGATION_ID");
  $fxfiles=$f[1] if($f[0] eq "FXFILES");
  $codetype=$f[1] if($f[0] eq "CODETYPE");
  if($f[0] eq "PACSettings")
  {
   $settings{HOSPICE}++ if(m/hospice/i);
   $settings{HHA}++ if(m/hha/i);
   $settings{SNF}++ if(m/snf/i);
  }
 }
}
close(INP);

#set up the vars to pull in select based on $counttype and $instance
my ($totstr,$medstr);
if(uc($instance) eq "PLDWHDBR")
{
 $totstr=" TOTAL_COUNT as CNT";
 $medstr=" MDCR_CNT as CNTMED ";
}
elsif(uc($instance) eq "PLDWH2DBR")
{
 if(uc($counttype) eq "PATIENT")
 {
  $totstr=" PTNT_CNT as CNT ";
  $medstr=" MDCR_PTNT_CNT as CNTMED ";
 }
 elsif(uc($counttype) eq "PROC")
 {
  $totstr=" PROC_CNT as CNT ";
  $medstr=" MDCR_PROC_CNT as CNTMED ";
 }
 elsif(uc($counttype) eq "CLAIM")
 {
  $totstr=" CLAIM_CNT as CNT ";
  $medstr=" MDCR_CLAIM_CNT as CNTMED ";
 }
}

my $dbhA = DBI->connect('DBI:Oracle:'.$instance,$username,$password)
  or die "could not connect to database: ".DBI->errstr;

#exit if px was selected
#4.15.2016 no need to exit for px codes any more
#if($codetype eq "px")
#{
 #print $lofh "ERROR: cannot do PAC projections for Px, exiting\n";
 #exit;
#}

my $natlpf;
if(defined $settings{SNF})
{
 #first do the national projection calc for SNF using WK
 $natlpf=&doWKnatproj;
 print $lofh "national proj factor = |$natlpf|\n";
}


my $sett;
my ($snfpopicntref,$snfpicntref,$snfpocntref);
my ($hhapopicntref,$hhapicntref,$hhapocntref);
my ($hospicepopicntref,$hospicepicntref,$hospicepocntref);

if(defined $settings{SNF})
{
 $sett="SNF";
 ($snfpopicntref,$snfpicntref,$snfpocntref)=&doCMSdiag($sett);
}
if(defined $settings{HHA})
{
 $sett="HHA";
 ($hhapopicntref,$hhapicntref,$hhapocntref)=&doCMSdiag($sett);
}
if(defined $settings{HOSPICE})
{
 $sett="HOSPICE";
 ($hospicepopicntref,$hospicepicntref,$hospicepocntref)=&doCMSdiag($sett);
}

#combine all 3 at piid poid level, piid level, and poid level
# apply projection to snf
#apply 1.1 to hha and hospice
#not doing consistency checks of final counts at the moment
#if same pi or po in multiple settings, just add up
my (%pacpopi,%pacpotot,%pacpitot);

foreach my $po (keys %$snfpopicntref)
{
 foreach my $pi (keys %{$snfpopicntref->{$po}})
 {
  my $cnt=int(0.5+$natlpf*$snfpopicntref->{$po}->{$pi});
  #print $lofh "$po\t$pi\t$cnt\n";
  $pacpopi{$po}{$pi}+=$cnt;
 }
}
foreach my $po (keys %$snfpocntref)
{
 my $cnt=int(0.5+$natlpf*$snfpocntref->{$po});
 $pacpotot{$po}+=$cnt;
}
foreach my $pi (keys %$snfpicntref)
{
 my $cnt=int(0.5+$natlpf*$snfpicntref->{$pi});
 $pacpitot{$pi}+=$cnt;
}

#use 1.1 pf for hha and hospice
$natlpf=1.1;
foreach my $po (keys %$hhapopicntref)
{
 foreach my $pi (keys %{$hhapopicntref->{$po}})
 {
  my $cnt=int(0.5+$natlpf*$hhapopicntref->{$po}->{$pi});
  #print $lofh "$po\t$pi\t$cnt\n";
  $pacpopi{$po}{$pi}+=$cnt;
 }
}
foreach my $po (keys %$hhapocntref)
{
 my $cnt=int(0.5+$natlpf*$hhapocntref->{$po});
 $pacpotot{$po}+=$cnt;
}
foreach my $pi (keys %$hhapicntref)
{
 my $cnt=int(0.5+$natlpf*$hhapicntref->{$pi});
 $pacpitot{$pi}+=$cnt;
}


foreach my $po (keys %$hospicepopicntref)
{
 foreach my $pi (keys %{$hospicepopicntref->{$po}})
 {
  my $cnt=int(0.5+$natlpf*$hospicepopicntref->{$po}->{$pi});
  #print $lofh "$po\t$pi\t$cnt\n";
  $pacpopi{$po}{$pi}+=$cnt;
 }
}
foreach my $po (keys %$hospicepocntref)
{
 my $cnt=int(0.5+$natlpf*$hospicepocntref->{$po});
 $pacpotot{$po}+=$cnt;
}
foreach my $pi (keys %$hospicepicntref)
{
 my $cnt=int(0.5+$natlpf*$hospicepicntref->{$pi});
 $pacpitot{$pi}+=$cnt;
}

open(OUT,">pac_projections.txt");
print OUT "HMS_POID\tHMS_PIID\tPractFacProjCount\tPractNatlProjCount\tFacProjCount\n";
foreach my $po (keys %pacpopi)
{
 foreach my $pi (keys %{$pacpopi{$po}})
 {
  #made this change 11.29.2016 - no useful info in outputing
  #records with either piid or poid blank, unless they are singletons.
  #assume there arent
  #1.23.2017 - for CPM, found lots of singletons in some buckets
  #so, reverting to outputing records with either missing
  if($pi ne "" || $po ne "")
  {
   print OUT "$po\t$pi\t$pacpopi{$po}{$pi}\t$pacpitot{$pi}\t$pacpotot{$po}\n";
  }
 }
}
close(OUT);

$dbhA->disconnect();


sub doCMSdiag
{
 my $sett=$_[0];

 print $lofh "entering doCMSdiag for |$sett|\n";
 my $aggr_name="'"."CMS_".$sett."'";
 $aggr_name=~s/ICE//;

 my (%cmspopicnt,%cmspocnt,%cmspicnt);

 #get doc org level data
 my $sql2=qq|select doc_id, org_id, $totstr
   from $aggregation_table where job_id=$aggregation_id
  and bucket_name=$bucket and aggr_level='DOCORGLEVEL' and
   aggr_name=$aggr_name|;

 print $lofh "$sql2\n";
 my $nrow=0;
 my $sth2=$dbhA->prepare($sql2) or die "could not prepare stmt ".$dbhA->errstr;
 $sth2->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth2->fetchrow_hashref())
 {
  $nrow++;
  my $piid=defined $ref->{DOC_ID} ? $ref->{DOC_ID} : "";
  my $poid=defined $ref->{ORG_ID} ? $ref->{ORG_ID} : "";
  $piid="" if($piid eq "MISSING");
  $poid="" if($poid eq "MISSING");
  
  $cmspopicnt{$poid}{$piid}+=$ref->{CNT};
 }
 $sth2->finish();
 print $lofh "Query returned $nrow piid at poid records\n";

 #get doc level data
 my $sql3=qq|select doc_id, $totstr
   from $aggregation_table where job_id=$aggregation_id
  and bucket_name=$bucket and aggr_level='DOCLEVEL' and
   aggr_name=$aggr_name|;

 print $lofh "$sql3\n";
 my $sth3=$dbhA->prepare($sql3) or die "could not prepare stmt ".$dbhA->errstr;
 $sth3->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth3->fetchrow_hashref())
 {
  my $piid=defined $ref->{DOC_ID} ? $ref->{DOC_ID} : "";
  $piid="" if($piid eq "MISSING");

  $cmspicnt{$piid}+=$ref->{CNT};

 }
 $sth3->finish();

 #get org level data
 my $sql4=qq|select org_id, $totstr
   from $aggregation_table where job_id=$aggregation_id
  and bucket_name=$bucket and aggr_level='ORGLEVEL' and
   aggr_name=$aggr_name|;

 print $lofh "$sql4\n";
 my $sth4=$dbhA->prepare($sql4) or die "could not prepare stmt ".$dbhA->errstr;
 $sth4->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth4->fetchrow_hashref())
 {
  my $poid=defined $ref->{ORG_ID} ? $ref->{ORG_ID} : "";
  $poid="" if($poid eq "MISSING");

  $cmspocnt{$poid}+=$ref->{CNT};
 }
 $sth4->finish();

 return (\%cmspopicnt,\%cmspicnt,\%cmspocnt);
}

sub doWKnatproj
{
 my $aggr_name="'"."WKMX_SNF"."'";

 my $sql1=qq|
  select distinct $totstr, $medstr from
   $aggregation_table where job_id=$aggregation_id
  and bucket_name=$bucket and aggr_level='NATL' and
   aggr_name=$aggr_name|;

  print $lofh "$sql1\n";
   my %natlcnts;
 $natlcnts{MDCR}=0;
 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  $natlcnts{TOTAL} = $ref->{CNT}; 
  $natlcnts{MDCR} = $ref->{CNTMED};
 }
 $sth1->finish();

 my $pf=1;
 if($natlcnts{MDCR} > 0)
 {
  $pf=$natlcnts{TOTAL}/$natlcnts{MDCR};
 }
 else
 {
  print $lofh "WARNING: SNF projection switch medicare counts =0\n";
  print $lofh "setting proj factor to 1\n";
 }
 return $pf;
}
