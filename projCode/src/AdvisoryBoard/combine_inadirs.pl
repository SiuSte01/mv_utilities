#!/usr/bin/perl -w
use strict;

#code to build an AB INA delivery directory similar to what it used
#  to look like on old db
#by copying over results and configs from multiple new DB INA directories
#  specified in an input list
#once this code is running smoothly, the copying can be changed to move
#  but until then, once the delivery is done, the source directories should
#  be deleted for space

#process:
#  create the new delivery directory via mkdir or in windows explorer
# create an input file containing the list of source directories
# only specify the parts after AdvisoryBoard, the rest is assumed
# cd into the new delivery directory, and run this script as follows:
#  perl ~drajagopalan/udrive/Network/DiagFocus/NewWHCode/ABTools/combine_inadirs.pl  <nameofinputfile>

if(scalar(@ARGV) == 0)
{
 print "need to specify input file name\n";
 exit;
}

my $fn=shift;
my @dirs;
open(INP,$fn) or die "cant open |$fn| for read\n";
while(<INP>)
{
 chomp;
 s/\015//g;
 push @dirs,$_;
}
close(INP);

#first validate all input dirs exist
foreach my $d (@dirs)
{
 my $fd="/vol/cs/clientprojects/AdvisoryBoard/".$d; 
 if(-e $fd)
 {
  print "|$fd| is good\n";
 }
 else
 {
  print "|$fd| does not exist\n";
 }
}

#now can proceed with copying
my $i=0;
foreach my $d (@dirs)
{
 $i++;
 my $fd="/vol/cs/clientprojects/AdvisoryBoard/".$d; 
 print "working on directory |$fd|\n";
 #first create a config directory and copy the contents from the source
 my $newconfig="config_".$i;
 system("rmdir $newconfig") if(-e $newconfig);
 system("mkdir $newconfig");
 my $srcconfig=$fd."/config";
 system("cp $srcconfig/*.tab $newconfig");
 system("cp $srcconfig/*.cfg $newconfig");

 #now read the networkConfigSettings.tab file in the newly created config
 #to figure out which directories of networks need to be copied over
 #In Oracle - directories are the NetworkName
 #In HPCC - directory is RELATION_TYPE_NetworkName (we have this format if DIRECTIONAL_FLAG is present)
 my $networklistf=$newconfig."/networkConfigSettings.tab";
 open(INP,$networklistf) or die "cant open |$networklistf| for read\n";
 my (%m,@nlist);
 my $isNewLayout = 0;
 while(<INP>)
 {
  chomp;
  my @f=split '\t';
  if($. == 1)
  {
   #figure out the column # of the network_name and relation_types fields
   for my $i (0 .. $#f)
   {
    my $lcnm = lc $f[$i];
    $m{$lcnm}=$i;
   }
   $isNewLayout = 1 if(defined $m{'directional_flag'}); # This is the HPCC layout if this field exists
   if(!defined $m{'network_name'})
   {
    print "problem, could not detect network_name column in file:\n";
    print "$srcconfig/networkConfigSettings.tab\n";
    print "exiting\n";
    exit;
   }
  }
  else
  {
   if ( $isNewLayout == 1 )
   {
	 my @relation = split( ',', $f[$m{'relation_types'}] );
	 for my $j (0 .. $#relation)
	 {
	  push @nlist,$relation[$j]."_".$f[$m{'network_name'}];
	 }
	}
   else
   {
	 push @nlist,$f[$m{'network_name'}];
   }
   
  }
 }
 close(INP);

 #now copy over each of the network name directories from source dir that 
 #exit
 foreach my $net (@nlist)
 {
  my $ndir=$fd."/".$net;
  if(!-e $ndir)
  {
   print "WARNING: can't find dir |$ndir|; skipping\n";
  }
  else
  {
   system("cp -r $ndir .");
  }
 }
}
