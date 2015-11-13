#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long qw(:config gnu_getopt);
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use Statistics::Basic qw(:all);
use Number::Format;

sub main_usage{
    print <<"usage";

Usage
    $FindBin::Script ACTION [OPTIONS]

Description
    Input is a data matrix, which defined as,
    1) frist row is sample names
    2) first column is observation names
    3) one row per observation
    4) one column per sample

Available Actions
    pcor   | calculate pairwise correlation
    filter | Filter the results from pcor 

    cor2sif| A shortcut for running both pcor and filter

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

###################
# Define Actions #
###################

sub load_matrix{
    my $fh = shift;
    my @matrix;
    while(<$fh>){
        chomp;
     	push @matrix, [split /\t/];
    }
    return \@matrix;
}

sub cal_cor{
    my ($matrix, $i, $j) = @_;
    my ($id1, @vector1) = @{$matrix->[$i]};
    my ($id2, @vector2) = @{$matrix->[$j]};
    my $cor = correlation([@vector1], [@vector2]);
    my $nf = Number::Format->new();
    $cor = $cor ne 'n/a' ? $nf->round($cor, 6) : $cor;
    return ($id1, $id2, $cor);
}

sub pcor{
    my $args = new_action(
        -desc => 'Calculate pairwise correlation using Statistic::Basic'
    );

    my $fh = $args->{in_fhs}->[0];
    my $matrix = load_matrix($fh);

    for(my $i = 1; $i <= $#{$matrix} - 1; $i++){
        for (my $j = $i + 1; $j <= $#{$matrix}; $j++){
            my ($id1, $id2, $cor) = cal_cor($matrix, $i, $j);;
            print "$id1\t$id2\t$cor\n";
        }
    }
}

sub filter{
    my $args = new_action(
        -desc => 'Filter results from pcor'
    );
    my @rates = (0.99, 0.95, 0.90, 0.80);

    my $in_fh = $args->{in_fhs}->[0];
    my $infile = $args->{infiles}->[0];
    my %fhs;
    for my $rate (@rates){
        open $fhs{$rate}->{cor}, ">", "$infile.$rate.cor" or die $!;
        open $fhs{$rate}->{sif}, ">", "$infile.$rate.sif" or die $!;
    }

    while(<$in_fh>){
        next unless /^(\S+)\t(\S+)\t(-?\d+\.\d+)$/;
        my ($id1, $id2, $cor) = ($1, $2, $3);
        for my $rate (@rates){
            if ($cor >= $rate){
                print {$fhs{$rate}->{cor}} $_;
                print {$fhs{$rate}->{sif}} "$id1\tco\t$id2\n";
            }
        }
    }
    
    for my $rate(keys %fhs){
        close $fhs{$rate}->{cor};
        close $fhs{$rate}->{sif};
    }
}

sub cor2sif{
    my $args = new_action(
        -desc => 'A shortcut for running both pcor and filter'
    );

    my $infile = $args->{infiles}->[0];
    system("perl $0 pcor $infile -o $infile.cor");
    system("perl $0 filter $infile.cor");
}

