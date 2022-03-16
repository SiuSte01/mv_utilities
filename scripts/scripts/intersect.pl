#!/usr/bin/env perl

#script to take 2 1-col txt files as arg and find common and unique

$f1=shift;
$f2=shift;

if($f1 eq '' || $f2 eq '')
{
 print "specify 2 files as argument\n";
 exit;
}

open(INP1,$f1) or die "cant open $f1\n";
while(<INP1>)
{
 chomp;
 s/^\s+//;
 s/\s+$//;
 $dat1{$_}++;
}
close(INP1);

open(INP2,$f2) or die "cant open $f2\n";
while(<INP2>)
{
 chomp;
 s/^\s+//;
 s/\s+$//;
 $dat2{$_}++;
}
close(INP2);

$both=0;
$only1=0;
$only2=0;
foreach $d1 (keys %dat1)
{
 if(defined $dat2{$d1})
 {
  $both++;
  print "found in both\t$d1\n";
 }
 else
 {
  $only1++;
  print "found in only $f1\t$d1\n";
 }
}
foreach $d2 (keys %dat2)
{
 unless(defined $dat1{$d2})
 {
  $only2++;
  print "found in only $f2\t$d2\n";
 }
}

print "counts\n";
print "both $both\n";
print "$f1 only $only1\n";
print "$f2 only $only2\n";
