#!/usr/bin/perl -w
use strict;

#code to loop over all buckets and create a single file
#containing the links and denom summaries, with denom appropriately **ed out

#this version is driven by an input file containing the type and the name mapped

#usage perl /nethome/drajagopalan/Network/DiagFocus/ABCode_NewDB/combinesummaries_input.pl <name of bucket map file>
#execute from the directory above all the networks

my $bf=shift;
if($bf eq "")
{
 print "must specify a filename containing the bucket mapping and type and tar file name\n";
 exit;
}
#bucket file must have:
#col1=directory name
#col2=type 
#col3=name for network that will appear in the summaries file
#col4=name  that will be used to create the tar file


#define the buckets here, with a 1 or 2 indicating number of groups
#i.e. dx only or dx to px
my (%bucketlist, %bucketmap, %tarname);
open(INP,$bf) or die "cant open |$bf|\n";
while(<INP>)
{
 chomp;
 s/\015//g;
 if($. > 1)
 {
  my @f=split '\t';
  if($#f == 3)
  {
   $bucketlist{$f[0]}=$f[1];
   $bucketmap{$f[0]}=$f[2];
   $tarname{$f[0]}=$f[3];
  }
  else
  {
   print "file |$bf| needs to contain 4 columns\n";
  }
 }
}
close(INP);


my $rootdir=`pwd`;
chomp($rootdir);

open(OUT,">combinedsummaries.txt");
print OUT "Network\tMetric\tQuintile\tCount\tMedian\tMean\tMin\tMax\n";
#my %act_header=('1'=>'Activity_Level','2'=>'Activity_Level_Dx');
#changed Dx to Grp1 10.06.2015
my %act_header=('1'=>'Activity_Level','2'=>'Activity_Level_Grp1');
foreach my $b (keys %bucketlist)
{
 print "bucket $b\n";
 my $df1=$rootdir."/$b/Comb/den1summarycounts.txt";
 open(INP1,$df1) or die "cant open $df1\n";
 while(<INP1>)
 {
  next if(m/median/);
  chomp;
  my @f=split '\t';
  print OUT "$bucketmap{$b}\t$act_header{$bucketlist{$b}}\t$f[0]\t$f[1]\t";
  print OUT $f[2] < 11 ? "*" : $f[2],"\t";
  print OUT $f[3] < 11 ? "*" : $f[3],"\t";
  print OUT $f[4] < 11 ? "*" : $f[4],"\t";
  print OUT $f[5] < 11 ? "*" : $f[5],"\n";
 }
 close(INP1);

 if($bucketlist{$b} == 2)
 {
  my $df2=$rootdir."/$b/Comb/den2summarycounts.txt";
  open(INP2,$df2) or die "cant open $df2\n";
  while(<INP2>)
  {
   next if(m/median/);
   chomp;
   my @f=split '\t';
   #print OUT "$bucketmap{$b}\tActivity_Level_Px\t$f[0]\t$f[1]\t";
   #changed to Grp2 on 10.06.2015
   print OUT "$bucketmap{$b}\tActivity_Level_Grp2\t$f[0]\t$f[1]\t";
   print OUT $f[2] < 11 ? "*" : $f[2],"\t";
   print OUT $f[3] < 11 ? "*" : $f[3],"\t";
   print OUT $f[4] < 11 ? "*" : $f[4],"\t";
   print OUT $f[5] < 11 ? "*" : $f[5],"\n";
  }
  close(INP2);
 }

 my $lf=$rootdir."/$b/Comb/linksummarycounts.txt";
 open(INP3,$lf) or die "cant open $lf\n";
 while(<INP3>)
 {
  next if(m/median/);
  chomp;
  print OUT "$bucketmap{$b}\tConnection_Strength\t$_\n";
 }
 close(INP3);
}
close(OUT);



