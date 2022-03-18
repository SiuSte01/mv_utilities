#!/usr/bin/env perl

=head1 NAME

manip

=head1 COMMAND

perl /vol/cs/clientprojects/Facility_Automation/scripts/manip.pl -config <settings.cfg>

=head1 DESCRIPTION

code template (insert description here)

=head1 AUTHOR

Stephen Siu mm/dd/yyyy

=cut

#Includes
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Cwd;
my $scriptDir;
my $libDir;
BEGIN
{
	$scriptDir = Cwd::abs_path(dirname($0));
	my $lib = dirname($scriptDir);
	if($lib =~ m/perl_utilities/)
	{
		$lib =~ s/perl_utilities.*/perl_utilities/;
		$libDir = Cwd::abs_path($lib) . "/lib";
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
	}
}
use lib $libDir;
use MiscFunctions;

my @ogArgs = @ARGV;
$| = 1;

my $timeBegin = time();

my $branch;
my $toBranch;
my $msg;
my $debug;

GetOptions(
	"branch=s"		=>\$branch,
	"toBranch=s"	=>\$toBranch,
	"msg=s"			=>\$msg,
	"debug"			=>\$debug
);

die "-branch parameter is required\n" unless $branch;

print Dumper(@ogArgs) if $debug;

my $memoryHash;
#THE ONLY THING YOU SHOULD UPDATE. MAPPINGS FOR ALL BRANCHES IN PERL_UTILITIES!!!
$memoryHash->{"BRANCHES"}->{"master"} = 1;
$memoryHash->{"BRANCHES"}->{"hotfix"} = 1;
$memoryHash->{"BRANCHES"}->{"dev"} = 1;
$memoryHash->{"BRANCHES"}->{"qa"} = 1;

die "Unrecognized branch: " . $branch . "\n" unless defined $memoryHash->{"BRANCHES"}->{$branch};


foreach my $x (keys %{$memoryHash->{"BRANCHES"}})
{
	next if $x eq $branch;
	next if $toBranch && $x ne $toBranch;
	print $x . "\n";
	my $commitMsg = "Merge branch '" . $branch . "' into " . $x;
	$commitMsg = $msg if $msg;
	system("git checkout " . $x);
	system("git merge " . $branch . " -m \"" . $commitMsg . "\"");
	system("git push");
}
system("git checkout " . $branch);

system("chmod 777 -R --silent .");

#MiscFunctions::screenPrintHash(hash=>$memoryHash,keysOnly=>"Y") if defined $memoryHash;
my $timeEnd = time();

my $runTime = $timeEnd - $timeBegin;
print "\nProcess Complete: " . $0 . "\n";
my $minutes = $runTime/60;
print "Job took " . $minutes . " minutes\n";

#End of main code







































