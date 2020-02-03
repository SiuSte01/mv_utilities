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
		my $sitePath = `python -m site | grep $lib | grep site-packages`;
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
my $file;
my $rm;
my $debug;

GetOptions(
	"branch=s"		=>\$branch,
	"toBranch=s"	=>\$toBranch,
	"file=s"			=>\$file,
	"rm"				=>\$rm,
	"debug"			=>\$debug
);

die "-branch parameter is required\n" unless $branch;
die "-file parameter is required\n" unless $file;

system("git checkout " . $branch . " &> /dev/null");
die "file: " . $file . " not found\n" if !$rm && !-e $file;
print Dumper(@ogArgs) if $debug;
#
my $memoryHash;
#THE ONLY THING YOU SHOULD UPDATE. MAPPINGS FOR ALL BRANCHES IN PERL_UTILITIES!!!
$memoryHash->{"BRANCHES"}->{"master"} = 1;
$memoryHash->{"BRANCHES"}->{"hotfix"} = 1;
$memoryHash->{"BRANCHES"}->{"dev"} = 1;
$memoryHash->{"BRANCHES"}->{"qa"} = 1;
$memoryHash->{"BRANCHES"}->{"tl"} = 1;

die "Unrecognized branch: " . $branch . "\n" unless defined $memoryHash->{"BRANCHES"}->{$branch};

my $commitMsg = "Merging " . $file . " from: " . $branch . " into other branches";
my $rmMsg = "Removing " . $file . " from: " . $branch;
foreach my $x (keys %{$memoryHash->{"BRANCHES"}})
{
	next if $x eq $branch && !$rm;
	next if $toBranch && $x ne $toBranch;
	print $x . "\n";
	system("git checkout " . $x);
	#You want to remove $file from all branches
	if($rm)
	{
		if(-e $file)
		{
			system("git rm " . $file);
			system("git commit -m \"" . $rmMsg . "\"");
			system("git push");
		}
		else
		{
			print "file: " . $file . " not found in branch: " . $branch . ". Nothing to git rm\n";
		}
	}
	#You want to copy a $file from $branch to other branches
	else
	{
		system("git checkout " . $branch . " " . $file);
		system("git add " . $file);
		system("git commit -m \"" . $commitMsg . "\"");
		system("git push");
	}
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







































