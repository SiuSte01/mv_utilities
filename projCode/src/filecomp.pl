#!/usr/bin/perl -w
use strict;

foreach my $f (glob("/vol/cs/clientprojects/mv_utilities/projCode/src/*pl /vol/cs/clientprojects/mv_utilities/projCode/src/*sas"))
#foreach my $f (glob("/vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/*pl /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/*sas"))
{
	print $f . "\n";
	my @z = split("\/",$f);
	print $z[$#z] . "\n";
	
	my $p = "/vol/cs/clientprojects/mv_utilities/projCode/src/" . $z[$#z];
	my $d = "/vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/" . $z[$#z];
	if(-e $p && -e $d)
	{
		system("cp $p prodf");
		system("cp $d devf");
		system("dos2unix prodf");
		system("dos2unix devf");
		system("rm difff") if(-e "difff");
		system("diff prodf devf > difff");
		my $diflines = `wc -l < difff`;
		chomp($diflines);
		$diflines += 0;
		if($diflines > 0)
		{
			my $sv = "diff_" . $z[$#z];
			system("mv difff " . $sv);
		}
	}
	elsif(-e $p)
	{
		print "|$d| does not exist\n";
	}
	elsif(-e $d)
	{
		print "|$p| does not exist\n";
	}
}
