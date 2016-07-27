#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    print <<"end_of_usage";

USAGE
    gfat.pl graphics $FindBin::RealScript ACTION [OPTIONS]

DESCRIPTION
    Draw genetic map figure

ACTION
    filter  | Filter data, remove duplicate entries, and make red overwriten
              black
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

main unless caller;

sub filter{
    my $args = new_action(
        -desc => "Filter data, remove duplicate entries, and make
                  red overwriten black",
    );
    my @fhs = get_in_fhs $args;
    my %data;
    my %c;
    for my $fh (@fhs){
        while(<$fh>){
            $c{all}++;
            die "Input data error $.: $_\n"
                unless /^(\d+)\t(\d+(\.\d+)?)\t(red|black)$/;
            my ($LG, $pos, $color) = ($1, $2, $4);
            unless(exists $data{$LG}->{$pos}){
                $c{unique}++;
                $data{$LG}->{$pos} = $color;
                $c{red}++ if $color eq 'red';
            }
            elsif($data{$LG}->{$pos} eq 'black' and
                   $color eq 'red'){
                $data{$LG}->{$pos} = 'red';
                $c{red}++;
            }
        }
    }
    for my $LG (sort {$a <=> $b} keys %data){
        for my $pos (sort {$a <=> $b} keys %{$data{$LG}}){
            print join("\t", $LG, $pos, $data{$LG}->{$pos})."\n";
        }
    }
    print STDERR "Total markers: $c{all}\n",
                 "Unique positions: $c{unique}\n",
                 "Red positions: $c{red}\n";
}
