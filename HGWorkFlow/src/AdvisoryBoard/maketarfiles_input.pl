#!/usr/bin/perl -w
use strict;

#code to loop over all buckets and create a tar file in each Comb dir
#and gzip it
#with file names mapped appropriately to their specification

#this version is driven by an input file containing the type and the name mapped

#usage perl /nethome/drajagopalan/Network/DiagFocus/ABCode_NewDB/maketarfiles.pl  <nameofbucketmapfile>
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

foreach my $b (keys %bucketlist)
{
 print "bucket $b\n";
 chdir("$b/Comb");
 my $linksname=$tarname{$b}."NetworkConnections.txt";
 my $denomname=$tarname{$b}."NetworkSummary.txt";
 my $tarname=$tarname{$b}.".tar";
 system("ln -s links_fordelivery.txt $linksname");
 system("ln -s denom_fordelivery.txt $denomname");
 system("tar -cvhf $tarname $linksname $denomname");
 system("gzip $tarname");
 chdir("../..");
}


