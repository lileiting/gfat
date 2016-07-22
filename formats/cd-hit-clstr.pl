#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

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

sub main{
    my %actions = (
        column => 'Reformat the *.clstr file into column style',
    );
    script_usage(%actions) unless @ARGV;
    &{\&{&get_action_name}};
}

main unless caller;

__END__
