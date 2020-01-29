#!/usr/bin/perl -w
use strict;
use DBI;

#9.28.2016
#stop using settings.mak, get the info from settings.cfg in config instead

#6/7/2016 change by dilip to account for piid/poid aggrs and piid/poid
#appearing in claim to patient ratio tables.
#this change should have been made about a month prior when we switched
#to piid/poid aggregations

#2 updates 12/7/2015 by dilip
#if poid tot < sumofpiid@poid/nphys, increase poid tot to sumofpiid@poid/nphys
# prior to this, used to increase to sumofpiid@poid - too much increase
# fixed the bug that prevented WK-only records from being used


#script to pull patient/claim count per doc and pos from CMS data
#points to pre-aggregated claim/patient count tables
#can eventually enhance this code to use these counts from both CMS and WK
#and pick the best value
#will do whatever settings are needed - ip/op/orboth
#output will be used to convert projected claim counts to proj pat cnts
#update 9.30 - pulls both cms and wk, and picks between them

#read the input.txt file from 1 level up and get the input parameters
my ($counttype,$vint,$codetype,$bucket,$username,$password,$instance);
my ($aggregation_table,$fxfiles,$aggregation_id,$hospsett);
my ($claim_pat_table);
open(INP,"../input.txt") or die "cant open ../input.txt\n";
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
  $claim_pat_table=$f[1] if($f[0] eq "CLAIM_PATIENT_TABLE");
  $aggregation_id=$f[1] if($f[0] eq "AGGREGATION_ID");
  $fxfiles=$f[1] if($f[0] eq "FXFILES");
  $codetype=$f[1] if($f[0] eq "CODETYPE");
  $hospsett=$f[1] if($f[0] eq "HospitalType");
 }
}
close(INP);

my $dbhA = DBI->connect('DBI:Oracle:'.$instance,$username,$password)
  or die "could not connect to database: ".DBI->errstr;

#grab the number of doc roles from the settings.cfg file
open(SETT,"../../../config/settings.cfg") or die "cant open settings.cfg\n";
my (%docs,$nphysroles);
while(<SETT>)
{
 chomp;
 s/\015//g;
 next if(m/^#/);
 if(m/PRACTITIONER_ROLES/)
 {
  $docs{att}++ if(m/attending/);
  $docs{oper}++ if(m/operating/);
  $docs{oth}++ if(m/other/);
  $nphysroles=scalar(keys %docs);
 }
}
close(SETT);

#get the aggr counts for both cms and wkub
my ($doctotalclaims_wk,$doctotalpatients_wk,$hosptotalclaims_wk,$hosptotalpatients_wk,$wkdoccountref,$wkhospcountref) = &getaggr("WKUB");
my ($doctotalclaims_cms,$doctotalpatients_cms,$hosptotalclaims_cms,$hosptotalpatients_cms,$cmsdoccountref,$cmshospcountref) = &getaggr("CMS");

$dbhA->disconnect();

#now integrate the cms and wkub values, pick higher claim count
my %docratio;
&combinecmswk(\%docratio,$wkdoccountref,$cmsdoccountref);
my %hospratio;
&combinecmswk(\%hospratio,$wkhospcountref,$cmshospcountref);


#now apply ratios to claims counts in hospital_projections.txt
#calculate median ratio for hospital and doc, to apply to hosp an docs
#not in cms data
my ($meddocratio,$medhospratio);
if(scalar(keys %docratio) > 0)
{
 my @ord1=sort{$docratio{$a} <=> $docratio{$b}} (keys %docratio);
 my $midpt=int(0.5*scalar(@ord1));
 $meddocratio=$docratio{$ord1[$midpt]};
 print "median doc ratio = $meddocratio\n";
}
else
{
 print "problem - not enough docs to calculate ratio\n";
 print "using the overall counts\n";
 $meddocratio= ($doctotalclaims_wk > $doctotalclaims_cms) ? 
   $doctotalpatients_wk/$doctotalclaims_wk : 
   $doctotalpatients_cms/$doctotalclaims_cms;
 print "median doc ratio = $meddocratio\n";
}
if(scalar(keys %hospratio) > 0)
{
 my @ord1=sort{$hospratio{$a} <=> $hospratio{$b}} (keys %hospratio);
 my $midpt=int(0.5*scalar(@ord1));
 $medhospratio=$hospratio{$ord1[$midpt]};
 print "median hosp ratio = $medhospratio\n";
}
else
{
 print "problem - not enough hospitals to calculate ratio\n";
 print "using the overall counts\n";
 $medhospratio= ($hosptotalclaims_wk > $hosptotalclaims_cms) ? 
   $hosptotalpatients_wk/$hosptotalclaims_wk : 
   $hosptotalpatients_cms/$hosptotalclaims_cms;
 print "median hosp ratio = $medhospratio\n";
}
open(OUTH,">medianhospratio.txt");
print OUTH "median hosp ratio = $medhospratio\n";
close(OUTH);


#read the claim count projection result
open(INP,"hospital_projections.txt");
my (%popicl,%pitotcl,%pototcl); #these are the claim counts
while(<INP>)
{
 chomp;
 my @f=split '\t';
 next if(m/HMS_PIID/i);
 $popicl{$f[1]}{$f[0]}=defined $f[2] && $f[2] ne "" ? $f[2] : 0;
 $pitotcl{$f[0]}=defined $f[3] && $f[3] ne "" ? $f[3] : 0;
 $pototcl{$f[1]}=defined $f[4] && $f[4] ne "" ? $f[4] : 0;
}
close(INP);

#now apply po and pi ratios to all data
my (%popi,%pitot,%potot); #these are the pat counts
foreach my $pi (keys %pitotcl)
{
 my $ratio=defined $docratio{$pi} ? $docratio{$pi} : $meddocratio;
 $pitot{$pi}=$ratio*$pitotcl{$pi};
}

foreach my $po (keys %pototcl)
{
 my $hratio=defined $hospratio{$po} ? $hospratio{$po} : $medhospratio;
 $potot{$po}=$hratio*$pototcl{$po};
 foreach my $pi (keys %{$popicl{$po}})
 {
  my $dratio=defined $docratio{$pi} ? $docratio{$pi} : $meddocratio;
  $popi{$po}{$pi}= $dratio*$popicl{$po}{$pi};
 }
}

#now round everything, with floor of 1
foreach my $pi (keys %pitot)
{
 my $rnd=int(0.5+$pitot{$pi});
 $pitot{$pi} = ($rnd > 0.001) ? $rnd : 1;
}

foreach my $po (keys %potot)
{
 my $rnd=int(0.5+$potot{$po});
 $potot{$po} = ($rnd > 0.001) ? $rnd : 1;
 foreach my $pi (keys %{$popi{$po}})
 {
  my $rnd=int(0.5+$popi{$po}{$pi});
  $popi{$po}{$pi} = ($rnd > 0.001) ? $rnd : 1;
 }
}

#need to apply corrections/sanity checks here
#the piid total cannot be greater than the sum of that piid over all poids total
#can happen due to rounding
#but it can be less - due to seeing same patient at multiple facilities
#need one pass through data to check this and adjust before output
my (%piposum);
my %poperpi;
my %sumatpoid;
#also count how many poids a piid appears in
#max piid cnt over all facs
my %facmax;
foreach my $po (keys %popi)
{
 foreach my $pi (keys %{$popi{$po}})
 {
  $piposum{$pi}+=$popi{$po}{$pi};
  $sumatpoid{$po}+=$popi{$po}{$pi};
  $poperpi{$pi}{$po}++;
  if(defined $facmax{$pi})
  {
   $facmax{$pi}=$popi{$po}{$pi} if($popi{$po}{$pi} > $facmax{$pi});
  }
  else
  {
   $facmax{$pi} = $popi{$po}{$pi};
  }
 }
}

#the piid national total cannot be less than count of piids patients
#at any single facility
foreach my $pi (keys %facmax)
{
 $pitot{$pi} = $facmax{$pi} if($pitot{$pi} < $facmax{$pi});
}

#next pass through to adjust
#if a piid is at only 1 poid, then piid at poid total must equal piid total
#else piid total cannot be > sum of piid at poids total
foreach my $pi (keys %pitot)
{
 my $npo=scalar(keys %{$poperpi{$pi}});
 if($npo == 1)
 {
  my $singlepo=(keys %{$poperpi{$pi}})[0];
  $pitot{$pi}=$popi{$singlepo}{$pi};
 }
 else
 {
  $pitot{$pi} = $piposum{$pi} if($pitot{$pi} > $piposum{$pi});
 }
}

#one more pass: check poid totals vs piid at poid counts
#no single piid at poid count should be larger than poid total
#if poid total is less, increast it
foreach my $po (keys %potot)
{
 foreach my $pi (keys %{$popi{$po}})
 {
  $potot{$po}=$popi{$po}{$pi} if($popi{$po}{$pi} > $potot{$po});
 }
}

#another pass: check poid totals vs sum of piids at poid.
#sum of piids at poids cannot be > number of phys roles * poid total
#if that is the case, increase poid total
foreach my $po (keys %potot)
{
 #12.7.2015 - changed what poid is set to if this test fails
 # prior adjustment was too high
 #$potot{$po} = $sumatpoid{$po}
 #now set poid total to be piid@poid total divided by # of doc roles
 $potot{$po} = int(0.5 + $sumatpoid{$po}/$nphysroles)
     if($sumatpoid{$po} > $potot{$po}*$nphysroles);
}

open(OUT,">patcnts.txt");
print OUT "HMS_PIID\tHMS_POID\tPractFacProjCount\tPractNatlProjCount\tFacProjCount\n";
foreach my $po (keys %popi)
{
 foreach my $pi (keys %{$popi{$po}})
 {
  die "Both piid and poid are blank!!" unless ($pi ne "" || $po ne "");
  if($pi eq "")
  {
   print OUT "\t$po\t\t\t$potot{$po}\n";
  }
  elsif($po eq "")
  {
   print OUT "$pi\t\t\t$pitot{$pi}\t\n";
  }
  else
  {
   print OUT "$pi\t$po\t$popi{$po}{$pi}\t$pitot{$pi}\t$potot{$po}\n";
  }
 }
}
close(OUT);


#now move the claims file to something else, and replace it with pat cnt file
system("mv hospital_projections.txt hospclaims.txt");
system("mv patcnts.txt hospital_projections.txt");


sub getaggr
{
 my $case=$_[0];

 my $aggr_name=$case."_".$hospsett."_CLAIM_PTNT_RATIO";
 $aggr_name="'".$aggr_name."'";

 #build the sql query to grab doc level claim and pat counts
 my $sql1=qq|
 select claim_count as clcnt, patient_count as ptcnt, doc_id
 from $claim_pat_table
 where aggr_name=$aggr_name and aggr_level='DOCLEVEL'
 and bucket_name=$bucket and job_id=$aggregation_id|;

 print "$sql1\n";
 
 open(OUT,">doccnts_$case.txt");
 my %pidata;
 my $doctotalclaims=0;
 my $doctotalpatients=0;
 print OUT "HMS_PIID\tPatientCount\tClaimCount\n";
 my $sth1=$dbhA->prepare($sql1) or die "could not prepare stmt ".$dbhA->errstr;
 $sth1->execute() or die "couldnt execute stmt ".$dbhA->errstr;
 while(my $ref = $sth1->fetchrow_hashref())
 {
  my $pi=$ref->{DOC_ID};
  if($pi ne "")
  {
   $pidata{$pi}{PT}+=$ref->{PTCNT};
   $pidata{$pi}{CL}+=$ref->{CLCNT};
   print OUT "$pi\t$ref->{PTCNT}\t$ref->{CLCNT}\n";
   $doctotalclaims+=$ref->{CLCNT};
   $doctotalpatients+=$ref->{PTCNT};
  }
 }
 $sth1->finish;

 #now do the org level clam/pat count
 my $sql2=qq|
 select claim_count as clcnt, patient_count as ptcnt, org_id
 from $claim_pat_table
 where aggr_name=$aggr_name and aggr_level='ORGLEVEL'
 and bucket_name=$bucket and job_id=$aggregation_id|;

 print "$sql2\n";

 #use a hash for the poid data to account for multiple pos mapping to single poid
 my %podata;
 my $hosptotalclaims=0;
 my $hosptotalpatients=0;
  my $sth2=$dbhA->prepare($sql2) or die "could not prepare stmt ".$dbhA->errstr;
  $sth2->execute() or die "couldnt execute stmt ".$dbhA->errstr;
  while(my $ref = $sth2->fetchrow_hashref())
  {
   my $po = $ref->{ORG_ID};
   $podata{$po}{PT}+=$ref->{PTCNT};
   $podata{$po}{CL}+=$ref->{CLCNT};
   $hosptotalclaims+=$ref->{CLCNT};
   $hosptotalpatients+=$ref->{PTCNT};
  }
  $sth2->finish;

 open(OUT2,">hospcnts_$case.txt");
 print OUT2 "HMS_POID\tPatientCount\tClaimCount\n";
 foreach my $po (keys %podata)
 {
  print OUT2 "$po\t$podata{$po}{PT}\t$podata{$po}{CL}\n";
 }
 close(OUT2);

 return ($doctotalclaims,$doctotalpatients,$hosptotalclaims,$hosptotalpatients,\%pidata,\%podata);
}


sub combinecmswk
{
 my ($resultref,$wkcountref,$cmscountref) = @_;

 foreach my $ent (keys %$cmscountref)
 {
  if(defined $wkcountref->{$ent})
  {
   #both cms and wk have counts, pick higher claim count to calc ratio, 
   #pick higher claim count of cms or wk to calc ratio
   #but the higher claim count must be >= 5, else dont calc ratio
   if($wkcountref->{$ent}->{CL} > $cmscountref->{$ent}->{CL})
   {
    $resultref->{$ent} = $wkcountref->{$ent}->{PT}/$wkcountref->{$ent}->{CL} 
         if($wkcountref->{$ent}->{CL} >= 5);
   }
   else
   {
   $resultref->{$ent} = $cmscountref->{$ent}->{PT}/$cmscountref->{$ent}->{CL} 
         if($cmscountref->{$ent}->{CL} >= 5);
   }
  }
  else
  {
   #only CMS has counts, use it to calc ratio if >= 5 claims
   $resultref->{$ent} = $cmscountref->{$ent}->{PT}/$cmscountref->{$ent}->{CL} 
          if($cmscountref->{$ent}->{CL} >= 5);
  }
 }

 #take care of the entities (pi or po) in wk that are not in CMS
 foreach my $ent (keys %$wkcountref)
 {
  #if(! defined $cmscountref)
  #changed this 12.7.2015
  if(! defined $cmscountref->{$ent})
  {
   $resultref->{$ent} = $wkcountref->{$ent}->{PT}/$wkcountref->{$ent}->{CL} 
         if($wkcountref->{$ent}->{CL} >= 5);
  }
 }

}
