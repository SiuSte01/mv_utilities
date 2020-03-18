#!/usr/bin/perl -w

#usage perl clean_migrations.pl dirty_migration_file
#deal with problem of these types of migrations:
# a->b
# b->c
#
# want to replace with a single record a->c

#read dirty migrations and store directed edges
my (%from,%to);
while(<>)
{
	chomp;
	if($. > 1)
	{
		my @f=split '\t';
		unless($f[0] eq $f[1]) #get rid of a->a
		{
			$from{$f[0]}{$f[1]}++;
			$to{$f[1]}{$f[0]}++;
		}
	}
}

#get rid of easy cycles
#a->b
#b->a
#assume no dups in from
foreach my $f (keys %from)
{
	if(defined $from{$f}) #need to check, cos might have got deleted
	{
		#print STDERR "$from{$f}\n";
		my @g=keys %{$from{$f}};
		#my $st=join("\t",@g);
		#print STDERR "$st\n";
		my $dest = (scalar(keys %{$from{$f}}) > 0) ? (keys %{$from{$f}})[0] : "";
		#print STDERR "|$f|\t|$dest|\n";
		#print STDERR "\n";
		if($dest eq "")
		{
			foreach my $d2 (keys %{$from{$dest}})
			{
				if($d2 eq $f)
				{
					##print "here\n";
					#print "deleting from $f $dest\n";
					delete $from{$f}{$dest};
					#print "deleting to $dest $f\n";
					delete $to{$dest}{$f};
					#print "deleting from $dest $d2\n";
					delete $from{$dest}{$d2};
					#print "deleting to $d2 $dest\n";
					delete $to{$d2}{$dest};
				}
			}
		}
	}
}

foreach my $f (keys %from)
{
	if(scalar (keys %{$from{$f}}) == 0)
	{ 
		delete $from{$f};
	}
}

#my $str=join("\t",(keys %from));
#print "$str\n";
#exit;

open(OUT,">cleaned_migrations.tab");
print OUT "Old_Value\tNew_Value\n";
#output the clean ones first
#assume only one outward edge due to prior cleanup
foreach my $f (keys %from)
{
	#print "DEBUG from=|$f|\n";
	#find the destination node 
	my $dest = (keys %{$from{$f}})[0];
	#print "DEBUG dest=|$dest|\n";
	#make sure destination is not a from as well
	#and make sure the from is not a to as well
	#print "DEBUG from hash with dest key |$from{$dest}|\n";
	#print "DEBUG to hash with from key |$to{$f}|\n";
	if((!defined $from{$dest}) && (!defined $to{$f}))
	{
		#print "clean\n";
		#this edge is clean, output and delete it from the hashes
		print OUT "$f\t$dest\n";
		delete $from{$f};
		delete $to{$dest};
	}
	else
	{
		#print "not clean\n";
	} 
}

#DEBUG
foreach my $f (keys %from)
{
	my $dest = (keys %{$from{$f}})[0];
	#print  "$f\t$dest\n";
}
#print "\n\n";

#now loop through all remaining source nodes that are not also destinations
#assumes from node wont go to multiple to nodes due to prior cleanup
foreach my $f (keys %from)
{
	#print "testing from = |$f|\n";
	unless(defined $to{$f})
	{
		#print "|$f| is not a to\n";
		my $fl=0;
		my $f2=$f;
		my $dest;
		while($fl == 0)
		{
			$dest = (keys %{$from{$f2}})[0];
			#print "found dest |$dest|\n";
			if(defined $from{$dest})
			{  
				#print "|$dest| is a from, keep going\n";
				delete $from{$f2};
				$f2=$dest;
			}
			else
			{
				#print "reached the terminal\n";
				$fl=1;
				delete $from{$f2};
			}
		}
		#print "cleaned\t$f\t$dest\n";
	}
}
