#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script

ACTIONS
    convert | Convert bootstrap format '1.00:[1000]' to '1000:1.00'

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}};
    }else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main() unless caller;

###########
# Actions #
###########

sub convert{
    my $action = new_action(
        -description => 'Convert bootstrap format from :1.00[1000] to 1000:1.00'
    );
    for my $in_fh (@{$action->{in_fhs}}){
        while(<$in_fh>){
            if(/^(.*):(-?\d+\.\d+)\[(\d+)\](.*)$/){
                my ($pre, $branch_len, $bootstrap, $suf) = ($1, $2, $3, $4);
                printf "$pre%d:%f$suf\n", $bootstrap, $branch_len;
            }
            else{
                print;
            }
        }
    }
}
