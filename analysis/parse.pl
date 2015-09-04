#!/usr/bin/env perl
use strict;
use warnings;
#use diagnostics;
use String::CRC32;
use File::Copy;

my (@getIn, @getOut, @transition, @rndRoom, @rndCentral);

foreach my $i (1..3000) {
	$getIn[$i] = 0;
	$getOut[$i] = 0;
	$transition[$i] = 0;
	$rndRoom[$i] = 0;
	$rndCentral[$i] = 0;
}

open(FILE1, $ARGV[0]) || die "Error with file\n";
my @lines = <FILE1>;
foreach my $line (@lines) {
	my @elements = split(/_/,$line);
	# print join(", ", @elements);
	# print $elements[2];
	if ($elements[2] =~ m/getIn/) {
	# if ($elements[2] eq 'getIn') {
		$getIn[$elements[0]] ++;
	}
	elsif ($elements[2] =~ m/getOut/) {
		$getOut[$elements[0]] ++;
	}
	elsif ($elements[2] =~ m/roomTransition/) {
		$transition[$elements[0]] ++;
	}
	elsif ($elements[2] =~ m/rndRoom/) {
		$rndRoom[$elements[0]] ++;
	}
	elsif ($elements[2] =~ m/rndCentral/) {
		$rndCentral[$elements[0]] ++;
	}
}

open (my $outFile, '>', 'data.csv');
foreach my $i (1..3000) {
	print $outFile "$i;$getIn[$i];$getOut[$i];$transition[$i];$rndRoom[$i];$rndCentral[$i]\n";
}