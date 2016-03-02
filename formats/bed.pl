#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    print <<"end_of_usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]
    
DESCRIPTION
    Manipulating bed files
    
OPTIONS
    isPcr   | Processing results from isPcr

end_of_usage
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

main() unless caller;

############################################################
# Defination of Actions                                    #
############################################################

sub isPcr{
    # bed - tab delimited format. Fields: chrom/start/end/name/score/strand
    my $args = new_action(
        -desc => 'Processing results from isPcr',
    );
    my %data;
    my @in_fhs = get_in_fhs $args;
    for my $fh (@in_fhs){
        while(<$fh>){
            chomp;
            my ($scf, $start, $end, $name, $score, $strand) = split /\t/;
            push @{$data{$name}}, [$scf, $start, $end, $name, $score, $strand];
        }
    }
    for my $name (sort {$a cmp $b} keys %data){
        my @array = @{$data{$name}};
        if(@array == 1){
            print join("\t", "0: ", @{$array[0]}),"\n";
        }
        else{
            @array = sort {$b->[4] <=> $a->[4]} @array;
            my @scores = map {$_->[4]} @array;
            my $rate = join("/", @scores);
            for my $info (@array){
                print join("\t", "$rate:", @$info),"\n";
            }
        }
    }
}


