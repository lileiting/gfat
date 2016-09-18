#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
our $in_desc = '<in.vcf|in.vcf.gz>';

sub main{
    my %actions = (
        filter => 'Filter VCF data'
    );
    &{ \&{run_action(%actions)} };
}

main unless caller;

sub filter{
    my $args = new_action(
        -desc => 'Filter VCF data',
        -options => {
            "missing|m=f" => 'Missing data rate.
                Allowed missing data =
                total number of progenies *
                missing data rate [default: 0.1]'
        }
    );

    my $missing = $args->{options}->{missing} // 0.1;

    for my $fh (@{$args->{in_fhs}}){
        my $number_of_progenies;
        while(<$fh>){
           print and next if /^##/;
           if(/^#[^#]/){
              # First two samples are parents
              my @f = split /\t/;
              $number_of_progenies = scalar(@f) - 9 - 2;
              print;
              next;
           }
           my @f = split /\t/;
           my @parents = @f[9,10];
           my @progenies = @f[11..$#f];
           # Do not allow missing data in parents
           next if $parents[0] =~ m{\./\.} or $parents[1] =~ m{\./\.};
           my $number_of_missing = 0;
           for my $progeny (@progenies){
               $number_of_missing++ if $progeny =~ m{\./\.};
           }
           $number_of_missing > $number_of_progenies * $missing ? next : print;
        }
    }
}

__END__
