#!/usr/bin/perl -w 
use strict;

#first read the poidvolcomp.txt to find out which old poids dropped
open(INP,"poidvolcomp.txt") or die "cant open poidvolcomp.txt\n";
my %drops;
while(<INP>)
{
 chomp;
 if($. > 1)
 {
  my @f=split '\t';
  $drops{$f[0]}++ if($f[2] > 0.5 && $f[1] < 0.5);
 }
}
close(INP);

my %migr;
open(INP,"cleaned_migrations.tab");
while(<INP>)
{
 if($. > 1)
 {
  chomp;
  my @f=split '\t';
 #only use rows where old poid dropped out of deliverable
  $migr{$f[0]}=$f[1] if(defined $drops{$f[0]}); 
 }
}
close(INP);

open(INP2,"namebased_migrations.txt");
while(<INP2>)
{
 if($. > 1)
 {
  chomp;
  my @f=split '\t';
  #$migr{$f[0]}=$f[1] unless(defined $migr{$f[0]});
  $migr{$f[0]}=$f[1]; #prefer the name based
 }
}
close(INP2);

open(OUT,">final_migrations.txt");
print OUT "Old_Value\tNew_Value\n";
foreach my $po (keys %migr)
{
 print OUT "$po\t$migr{$po}\n";
}
close(OUT);
