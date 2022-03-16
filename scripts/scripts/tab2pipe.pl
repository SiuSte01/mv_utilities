#!/usr/bin/perl

# tab2pipe.pl
# converts all files in directory from tab delim to pipe delim format

my @files = glob('*.tab');

print "Converting .txt files to tab delim format ...\n";

foreach my $file(@files){
	`perl -pe 's/\t/\|/g' $file > $file.txt`;
}

print "All files converted. \n";