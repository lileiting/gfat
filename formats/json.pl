#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use JSON;
use Data::Dumper;

sub main_usage{
    print <<"usage";

$FindBin::Script ACTION [OPTIONS]

ACTIONS
    view  | view JSON data

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}}; 
    }
    else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main unless caller;

############################################################
# Actions
############################################################

sub view{
    my $args = new_action(
        -desc => 'view JSON'
    );
    my $json_text;
    for my $fh (@{$args->{in_fhs}}){
        local undef $/;
        $_ = <$fh>;
        $json_text .= $_; 
    }
    my  $perl_scalar = from_json($json_text);
    print Dumper($perl_scalar);

}







