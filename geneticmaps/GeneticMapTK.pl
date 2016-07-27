#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use File::Basename;

print "
NAME
    GeneticMapTK - a toolkit for genetic map data analyses

AVAILABLE SCRIPTS

";
my @scripts = glob "$FindBin::RealBin/*.pl";
for (sort {$a cmp $b} @scripts){
    my $scriptname = basename $_;
    next if $scriptname eq $FindBin::RealScript;
    print "    $scriptname\n";
}
print "\n";

