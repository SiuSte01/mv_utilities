#!/usr/bin/env perl

#Includes
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Cwd;
my $scriptDir;
my $libDir;
my $envName;
my $rScript;
BEGIN
{
	$scriptDir = Cwd::abs_path(dirname($0));
	my $lib = dirname($scriptDir);
	if($lib =~ m/mv_utilities/)
	{
		my $mvDir = $lib;
		$lib =~ s/mv_utilities.*/perl_utilities/;
		$mvDir =~ s/mv_utilities.*/mv_utilities/;
		$libDir = Cwd::abs_path($lib) . "/lib";
		$rScript = $mvDir . "/scripts/scripts/appendixA/make_appendix_A_from_code_list.R";
	}
	else
	{
		$lib = `conda info -e | grep '*'`;
		$lib =~ s/^.*\*//;
		$lib =~ s/^\s+|\s+$//g;
		my $sitePath = `python -m site | grep $lib | grep -P "site-packages'"`;
		$sitePath =~ s/^\s+|\s+$//g;
		$sitePath =~ s/('|,)//g;
		$libDir = $sitePath . "/lib";
		$rScript = $sitePath . "/scripts/scripts/appendixA/make_appendix_A_from_code_list.R";
	}
	$envName = `conda info -e | grep '*'`;
	$envName =~ s/\*.*//;
	$envName =~ s/^\s+|\s+$//g;
}
use lib $libDir;
use MiscFunctions;

my @ogArgs = @ARGV;
if(-e "debug")
{
	print "ARGV for " . $0 . ":\n";
	print Dumper(@ogArgs);
}

my $timeBegin = time();

my $cgmFile;
my $debug;

GetOptions(
   "cgmFile=s"	=>\$cgmFile,
	"debug"		=>\$debug
);

die "-cgmFile parameter is required\n" unless $cgmFile;
my $cgmDir = dirname($cgmFile);

system("Rscript " . $rScript . " " . $cgmFile);
print "appendixA created at " . $cgmDir . "/appendixA.tab. If copying into excel, make sure to format all cells as text to avoid dropped 0's.\n";

system("chmod 777 -R --silent " . $cgmDir);

my $timeEnd = time();

my $runTime = $timeEnd - $timeBegin;
#print "\nProcess Complete: " . $0 . "\n";
my $minutes = $runTime/60;
#print "Job took " . $minutes ." minutes\n";

#End of main code




































