#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]

DESCRIPTION

AVAILABLE ACTIONS
    column | Reformat the *.clstr file into column style

usage
    exit
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    main_usage unless $action =~ /^[a-z]/;
    if(defined &{\&{$action}}){
        &{\&{$action}}
    }else{
        die "CAUTION: Action $action was not defined!";
    }
}

main unless caller;

sub column{
    my $args = new_action(
        -desc => 'Reformat the *.clustr file into column style'
    );

    my $cluster;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            if(/^>Cluster (\d+)/){
                $cluster = $1;
            }
            elsif(/^(\d+)\t(\d+)[a-z]{2}, >(\S+)\.\.\./){
                print "cluster$cluster\t$1\t$2\t$3\n";
            }else{
                die "CAUTION: unexpected format: $_";
            }
        }
    }
}

__END__
