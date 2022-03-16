#!/usr/bin/perl -w
use strict;

#since Karthik's poid joining does not seem to have worked completely, try bring in the 
#poids from the xwalk and check if different, if either poid col is blank
my %npi2poid;
open(NPX,"../npi_poids.txt");
while(<NPX>)
{
 chomp;
 s/\015//g;
 if($. > 1)
 {
  my @f=split '\t';
  $npi2poid{$f[0]}=$f[1];
 }
}
close(NPX);

my %clia2poid;
open(CLX,"../clia2poid_20160720.txt");
while(<CLX>)
{
 chomp;
 s/\015//g;
 if($. > 1)
 {
  my @f=split '\t';
  $clia2poid{$f[0]}=$f[1];
 }
}
close(CLX);


open(F1,"LabClaims_wProfilesScores_20160725.txt");
#grab records that have a match in column 23 and poids are not missing and different
my %data;
open(OUT,">noxwalk.txt");
while(<F1>)
{
 chomp;
 s/\015//g;
 if($. > 1)
 {
  my @f=split '\t';
  if($#f == 22)
  {
   #only have the match column, check poids myself
   $f[2]=~s/\s+//g;
   $f[3]=~s/\s+//g;
   print OUT "$f[0]\t$f[2]\n" if($f[2] eq "");
   print OUT "$f[1]\t$f[3]\n" if($f[3] eq "");
   if(($f[2] ne "") && ($f[3] ne "") && ($f[2] ne $f[3]) && ($f[22] == 1))
   {
    my $str=$f[0]."\t".$f[1]."\t".$f[2]."\t".$f[3];
    $data{$str}++;
   }
   elsif(($f[2] eq "") || ($f[3] eq "") && ($f[22] == 1))
   {
    my $npipoid="";
    my $cliapoid="";
    if($f[2] eq "")
    {
     $npipoid = defined $npi2poid{$f[0]} ? $npi2poid{$f[0]} : "";
    }
    if($f[3] eq "")
    {
     $cliapoid = defined $clia2poid{$f[0]} ? $clia2poid{$f[0]} : "";
    }
    if(($npipoid ne "") && ($cliapoid ne ""))
    {
     my $str=$f[0]."\t".$f[1]."\t".$npipoid."\t".$cliapoid;
     $data{$str}++;
    }
   }
  }
 }
}
close(F1);

open(F2,"Lab_Work.txt");
while(<F2>)
{
 chomp;
 s/\015//g;
 if($. > 1) 
 {
  my @f=split '\t';
  if($#f == 23)
  {
   #have the match and match but different poid colums
   $f[2]=~s/\s+//g;
   $f[3]=~s/\s+//g;
   print OUT "$f[0]\t$f[2]\n" if($f[2] eq "");
   print OUT "$f[1]\t$f[3]\n" if($f[3] eq "");
   if(($f[2] ne "") && ($f[3] ne "") && ($f[2] ne $f[3]) && ($f[23] == 1))
   {
    my $str=$f[0]."\t".$f[1]."\t".$f[2]."\t".$f[3];
    $data{$str}++;
   }
   #not loading poid xwalk here, because Karthik says poids are different
  }
  elsif($#f >= 22)
  {
   $f[2]=~s/\s+//g;
   $f[3]=~s/\s+//g;
   print OUT "$f[0]\t$f[2]\n" if($f[2] eq "");
   print OUT "$f[1]\t$f[3]\n" if($f[3] eq "");
   if(($f[2] ne "") && ($f[3] ne "") && ($f[2] ne $f[3]) && ($f[22] == 1))
   {
    my $str=$f[0]."\t".$f[1]."\t".$f[2]."\t".$f[3];
    $data{$str}++;
   }
   elsif(($f[2] eq "") || ($f[3] eq "") && ($f[22] == 1))
   {
    my $npipoid="";
    my $cliapoid="";
    if($f[2] eq "")
    {
     $npipoid = defined $npi2poid{$f[0]} ? $npi2poid{$f[0]} : "";
    }
    if($f[3] eq "")
    {
     $cliapoid = defined $clia2poid{$f[0]} ? $clia2poid{$f[0]} : "";
    }
    if(($npipoid ne "") && ($cliapoid ne ""))
    {
     my $str=$f[0]."\t".$f[1]."\t".$npipoid."\t".$cliapoid;
     $data{$str}++;
    }
   }
  }
 }
}
close(F2);
close(OUT);

open(OUT,">lab_npi_clia_matches.txt");
print OUT "NPI\tCLIA\tNPI_POID_20160725\tCLIA_POID_20160725\n";
foreach my $str (keys %data)
{
 print OUT "$str\n";
}
