#!/usr/bin/perl -w
use strict;

my $projtype=shift;
my $user = getpwuid($<);
my $emailaddr=$user."\@healthmarketscience.com";

my $loc=`pwd`;
chomp($loc);
$loc=~s/^\/vol\/cs\/clientprojects\///;
$loc=~s/\/Projections$//;

system("echo $loc | mail -s '$projtype Complete' $emailaddr");
