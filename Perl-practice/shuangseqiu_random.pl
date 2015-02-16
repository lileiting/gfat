#!/usr/bin/perl

use warnings;
use strict;

sub main{
    my $red_max  = 33;
    my $blue_max = 16;

    for(1..100){
        my @n;
        my %hash;
        for(1..6){
            my $red = int(rand($red_max) + 1);
            redo if $hash{$red};
            push @n, $red;
            $hash{$red}++;
        }
        @n = sort{$a <=> $b}@n;
        push @n, int(rand($blue_max) + 1);
        printf "%4d%4d%4d%4d%4d%4d%4d\n",@n;
    }
}

main;
