#!/usr/bin/env perl

use warnings;
use strict;
use List::Util qw/max/;

my @wd_files = glob "bsub.err.* bsub.out.*";

my $n = 1;
if(@wd_files > 0){
    my @num = map{s/^bsub\.(err|out)\.//}@wd_files;
    map{next unless /^\d+$/}@num;
    $n = max(@num);
}
my $err = qq/bsub.err.$n/;
my $out = qq/bsub.out.$n/;

my $cmd = "bsub -e $err -o $out @ARGV\n";
print $cmd;
