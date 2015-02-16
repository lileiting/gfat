#!/usr/bin/perl

use warnings;
use strict;

sub main{
    my $red_max  = 33;
    my $blue_max = 16;

    for(1..100){
        my %hash;
        $hash{int(rand($red_max) + 1)}++ until keys %hash == 6;
        printf "%4d%4d%4d%4d%4d%4d%4d\n",
            (sort{$a <=> $b}(keys %hash)), int(rand($blue_max) + 1);
    }
}

main;
