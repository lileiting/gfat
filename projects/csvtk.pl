#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
our $in_desc = '<in.csv> [<in.csv> ...]';

sub main{
    my %actions = (
        csv2tab => 'Convert csv file to tab file'
    );
    &{ \&{run_action( %actions )} };
}

sub csv2tab{
    my $args = new_action(
        -desc => 'Convert csv file to tab file'
    );

    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            s/,/\t/g;
            s/"//g;
            print;
        }
    }
}

main unless caller;

__END__
