#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::SeqAction;

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]

ACTIONS
    acclist | Print accession numbers for a sequence file
    idlist  | Print ID list for a sequence file

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    our $format = 'fasta';
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}}; 
    }
    elsif(GFAT::SeqAction->can($action)){
        GFAT::SeqAction->$action();
    }
    else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main() unless caller;

####################
# Sequence Actions #
####################


