#!/usr/bin/perl

use warnings;
use strict;

print STDERR "-" x 12,"ASCII code table","-" x 12, "\n";
print STDERR "Bin\tOct\tDec\tHex\tChar\n";

foreach my $val (33..126){
	printf "%07b\t%03o\t%d\t%02x\t%c\n",$val,$val,$val,$val,$val;
}

print STDERR "-" x 40,"\n";
