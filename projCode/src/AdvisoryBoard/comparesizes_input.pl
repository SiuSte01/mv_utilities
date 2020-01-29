#!/usr/bin/perl -w
use strict;

#pass old dir as 2nd argument
#my $olddir="/vol/cs/clientprojects/AdvisoryBoard/2015_03_27_Referral_Networks_Refresh";

my $bfile=shift;
if($bfile eq "")
{
 print "must specify bucket input file containing dir name, type, summary name and tarfilename\n";
 exit;
}

my $olddir=shift;
if($olddir eq "")
{
 print "must specify full path containing previous dir name\n";
 exit;
}

my @buckets;
open(INP,$bfile) or die "cant open |$bfile|\n";
while(<INP>)
{
 chomp;
 if($. > 1)
 {
  my @f=split '\t';
  push @buckets,$f[0];
 }
}
close(INP);

my (%data);
foreach my $b (@buckets)
{
 print "bucket = |$b|\n";
 chdir($b);
 foreach my $dir qw (CMSNoPtB CMSwPtB WK EMD)
 {
  print "dir = |$dir|\n";
  if(-e $dir)
  {
   chdir($dir);
   my $odir=$olddir."/".$b."/".$dir;
   #do new and old denom
   if(-e "denom.txt")
   {
    my $n=`wc -l < denom.txt`;
    $data{$b}{$dir}{denom}{N}=$n;
   }
   elsif(-e "denom.txt.gz")
   {
    my $n=`zcat denom.txt.gz | wc -l`;
    $data{$b}{$dir}{denom}{N}=$n;
   }
   if(-e "$odir/denom.txt")
   {
    my $o=`wc -l < $odir/denom.txt`;
    $data{$b}{$dir}{denom}{O}=$o;
   }
   elsif(-e "$odir/denom.txt.gz")
   {
    my $o=`zcat $odir/denom.txt.gz | wc -l`;
    $data{$b}{$dir}{denom}{O}=$o;
   }

   #do new and old links
   if(-e "links.txt")
   {
    my $n=`wc -l < links.txt`;
    $data{$b}{$dir}{links}{N}=$n;
   }
   elsif(-e "links.txt.gz")
   {
    my $n=`zcat links.txt.gz | wc -l`;
    $data{$b}{$dir}{links}{N}=$n;
   }
   if(-e "$odir/links.txt")
   {
    my $o=`wc -l < $odir/links.txt`;
    $data{$b}{$dir}{links}{O}=$o;
   }
   elsif(-e "$odir/links.txt.gz")
   {
    my $o=`zcat $odir/links.txt.gz | wc -l`;
    $data{$b}{$dir}{links}{O}=$o;
   }
   chdir("..");
  }
 }

 chdir("Comb");
 #do new and old denom for delivery
 my $odir=$olddir."/".$b."/Comb"; 
 if(-e "denom_fordelivery.txt")
 {
  my $n=`wc -l < denom_fordelivery.txt`;
  $data{$b}{Comb}{denom}{N}=$n;
 }
 elsif(-e "denom_fordelivery.txt.gz")
 {
  my $n=`zcat denom_fordelivery.txt.gz | wc -l`;
  $data{$b}{Comb}{denom}{N}=$n;
 }
 if(-e "$odir/denom_fordelivery.txt")
 {
  my $o=`wc -l < $odir/denom_fordelivery.txt`;
  $data{$b}{Comb}{denom}{O}=$o;
 }
 elsif(-e "$odir/denom_fordelivery.txt.gz")
 {
  my $o=`zcat $odir/denom_fordelivery.txt.gz | wc -l`;
  $data{$b}{Comb}{denom}{O}=$o;
 }

 #do new and old links for delivery
 if(-e "links_fordelivery.txt")
 {
  my $n=`wc -l < links_fordelivery.txt`;
  $data{$b}{Comb}{links}{N}=$n;
 }
 elsif(-e "links_fordelivery.txt.gz")
 {
  my $n=`zcat links_fordelivery.txt.gz | wc -l`;
  $data{$b}{Comb}{links}{N}=$n;
 }
 if(-e "$odir/links_fordelivery.txt")
 {
  my $o=`wc -l < $odir/links_fordelivery.txt`;
  $data{$b}{Comb}{links}{O}=$o;
 }
 elsif(-e "$odir/links_fordelivery.txt.gz")
 {
  my $o=`zcat $odir/links_fordelivery.txt.gz | wc -l`;
  $data{$b}{Comb}{links}{O}=$o;
 }
 chdir("..");

 chdir("..");
}

open(OUT,">compareresults.txt");
foreach my $b (keys %data)
{
 foreach my $dir (keys %{$data{$b}})
 {
  foreach my $f qw (denom links)
  {
   if($data{$b}{$dir}{$f}{O} > 0)
   {
    my $ratio=sprintf("%.2f",$data{$b}{$dir}{$f}{N}/$data{$b}{$dir}{$f}{O});
    print OUT "$b\t$dir\t$f\t$ratio\n";
   }
   else
   {
    print "problem |$b|\t|$dir|\t|$f|\t|$data{$b}{$dir}{$f}{O}\n";
   }
  }
 }
}
close(OUT);

