#!/usr/bin/env perl

use warnings;
use strict;
use File::Basename;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub validate{
    my $args = new_action(
        -desc => 'validate if the matrix is correct',
        -options => {
            "csv|c" => 'csv format'
        }
    );

    my $sep = $args->{options}->{csv} ? ',' : "\t";

    my %stats;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            my @list = split /$sep/;
            my $list = @list;
            my $missing = grep {/^$/} @list;
            $stats{list}->{$list}++;
            $stats{missing}->{$missing}++;
            print "Line: $.; number of columns: $list; number of missing: $missing\n";
        }
    }
    for my $list (keys %{$stats{list}}){
        print "List size: ", $list, "\t", $stats{list}->{$list}, "\n";
    }

    for my $missing (keys %{$stats{missing}}){
        print "Missing: ", $missing, "\t", $stats{missing}->{$missing}, "\n";
    }
}

sub main{
    my %actions = (
        'validate' => 'validate if the matrix is correct',
    );
    script_usage(%actions) unless @ARGV;
    &{\&{&get_action_name}};
}

main unless caller;

__END__
