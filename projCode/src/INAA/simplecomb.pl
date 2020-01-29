#!/usr/bin/perl -w
use strict;

#mod on 11.11.2015 - if guid is being written for AB special output
# also write connection type (PIIDPIID, PIIDPOID, POIDPOID) to denom file

#check if counts are to be added to links via input options
my $addcnts="no";
if(-e "../inputs")
{
 $addcnts=`grep AddSharedPatientCounts ../inputs | cut -f2`;
 chomp($addcnts);
 print "Add Shared Patient Counts set to |$addcnts|\n";
}
$addcnts = lc $addcnts;

#check if counts are to be added to denom via input options
my $adddencnts="no";
if(-e "../inputs")
{
 $adddencnts=`grep AddDenomPatientCounts ../inputs | cut -f2`;
 chomp($adddencnts);
 print "Add Denom Patient Counts set to |$adddencnts|\n";
}
$adddencnts = lc $adddencnts;

#check if guid to be added to links and denom via input options
my $writeguid="no";
my $guid="";
if(-e "../inputs")
{
 $guid=`grep Guid ../inputs | cut -f2`;
 chomp($guid);
 $writeguid = "yes" if(length($guid) > 0);
 print "guid is set to |$guid|\n" if($writeguid eq "yes");
}

#check if delimiter is specified in input for links and denom files
my $delim="\t";
if(-e "../inputs")
{
 my $txt=`grep Delim ../inputs | cut -f2`;
 chomp($txt);
 if(length($txt) > 0)
 {
  $delim=$txt;
  $delim= "|" if(lc($delim) eq "pipe");
 }
}
print "delimiter is = |$delim|\n";


open(INP,"links.txt") or die "cant open links.txt\n";
open(OUT,">links_fordelivery.txt");
my (%out,%in);
my @hvals;
push @hvals,"GUID" if($writeguid eq "yes");
push @hvals,"HMS_ID1";
push @hvals,"HMS_ID2";
push @hvals,"ConnStrRank";
push @hvals,"SharedPatientCount" if($addcnts eq "yes");
my $h=join($delim,@hvals);
print OUT "$h\n";
while(<INP>)
{
 chomp;
 next if(m/^VAR1/i);
 my @f=split '\t';
 my @g=split(':',$f[0]);
 $out{$g[0]}{$g[1]}++;
 $in{$g[1]}{$g[0]}++;
 my @v;
 push @v,$guid if($writeguid eq "yes");
 push @v,$g[0];
 push @v,$g[1];
 push @v,$f[2];
 push @v,$f[1] if($addcnts eq "yes");
 my $str=join($delim,@v);
 print OUT "$str\n";
}
close(INP);
close(OUT);

my $ngr=1;
if(-e "../inputs")
{
 $ngr=`grep Groups ../inputs | cut -f2`;
 $ngr+=0;
}

#figure out the group 1 and group 2 types if writeguid is yes
my $grp1ent="";
my $grp2ent="";
if($writeguid eq "yes")
{
 if(-e "../inputs")
 {
  my $txt=`grep Grp1Ent ../inputs | cut -f2`;
  chomp($txt);
  if(length($txt) > 0)
  {
   $grp1ent=$txt."ID";
  }
  if($ngr == 2)
  {
   $txt=`grep Grp2Ent ../inputs | cut -f2`;
   chomp($txt);
   if(length($txt) > 0)
   {
    $grp2ent=$txt."ID";
   }
  }
  else
  {
   $grp2ent=$grp1ent;
  }
 }
 print "Grp1Ent is = |$grp1ent|\n";
 print "Grp2Ent is = |$grp2ent|\n";
}

open(INP2,"rankeddenom.txt") or die "cant open rankeddenom.txt\n";
open(OUT2,">denom_fordelivery.txt");
if($ngr == 1)
{
 my @hvals;
 push @hvals,"GUID" if($writeguid eq "yes");
 push @hvals,"HMS_ID";
 push @hvals,"Grp1Rank";
 push @hvals,"Grp1PatCnt" if($adddencnts eq "yes");
 push @hvals,"NumConnEnt";
 push @hvals,"ConnType" if($writeguid eq "yes");
 my $h=join($delim,@hvals);
 print OUT2 "$h\n";
}
elsif($ngr == 2)
{
 #my $str1=($adddencnts eq "yes") ? "DxPatCnt\t" : "";
 #my $str2=($adddencnts eq "yes") ? "PxPatCnt\t" : "";
 #changed to grp1 and grp2 10.08.15
 my $str1=($adddencnts eq "yes") ? "Grp1PatCnt\t" : "";
 my $str2=($adddencnts eq "yes") ? "Grp2PatCnt\t" : "";
 #changed to grp1 and grp2 10.08.15
 my @hvals;
 push @hvals,"GUID" if($writeguid eq "yes");
 push @hvals,"HMS_ID";
 push @hvals,"Grp1Rank";
 push @hvals,"Grp1PatCnt" if($adddencnts eq "yes");
 push @hvals,"Grp2Rank";
 push @hvals,"Grp2PatCnt" if($adddencnts eq "yes");
 push @hvals,"NumConnGrp2Ent";
 push @hvals,"NumConnGrp1Ent";
 push @hvals,"ConnType" if($writeguid eq "yes");
 my $h=join($delim,@hvals);
 print OUT2 "$h\n";
}
while(<INP2>)
{
 chomp;
 next if(m/^HMS/i);
 my @f=split '\t';
 #only output docs in network
 my @v;
 if(defined $in{$f[0]} || defined $out{$f[0]})
 {
  if($ngr == 1)
  {
   push @v,$guid if($writeguid eq "yes");
   push @v,$f[0];
   push @v,$f[2];
   push @v,$f[1] if($adddencnts eq "yes");
  }
  elsif($ngr == 2)
  { 
   my $grp2rank= ($#f >= 4) ? $f[4] : "";
   my $grp1rank= ($#f >= 3) ? $f[3] : "";
   my $grp2cnt=($f[2] ne "") ? $f[2] : 0;
   my $grp1cnt=($f[1] ne "") ? $f[1] : 0;
   if($adddencnts eq "yes")
   {
    push @v,$guid if($writeguid eq "yes");
    push @v,$f[0];
    push @v,$grp1rank;
    push @v,$grp1cnt;
    push @v,$grp2rank;
    push @v,$grp2cnt;
   }
   else
   {
    push @v,$guid if($writeguid eq "yes");
    push @v,$f[0];
    push @v,$grp1rank;
    push @v,$grp2rank;
   }
  }
  if($ngr == 1)
  {
   my $deg=0;
   $deg += (defined $in{$f[0]}) ? scalar(keys %{$in{$f[0]}}) : 0;
   $deg += (defined $out{$f[0]}) ? scalar(keys %{$out{$f[0]}}) : 0;
   push @v,$deg;
  }
  elsif($ngr == 2)
  {
   push @v, defined $out{$f[0]} ? scalar(keys %{$out{$f[0]}}) : 0;
   push @v, defined $in{$f[0]} ? scalar(keys %{$in{$f[0]}}) : 0;
  }
  if($writeguid eq "yes")
  {
   my $ctype=$grp1ent.$grp2ent;
   push @v,$ctype;
  }
  my $str=join($delim,@v);
  print OUT2 "$str\n";
 }
}
close(OUT2);
close(INP2);
