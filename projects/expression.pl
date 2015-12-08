#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

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
    tissue_specific | find tissue specific expressed genes
    unexpressed     | list unexpressed genes (value equals to -2 for 
                      all samples)
    matrix2list     | convert a matrix to a 2-column list

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

sub tissue_specific{
    my $args = new_action(
        -desc => 'Find tissue specific genes',
        -options => {
            "diff|d=f" => 'Cutoff of difference value between the best NFPKM
                           and the second best NFPKM [default: 0.01]',
            "min|i=f"  => 'Cutoff value for the best NFPKM [default: 0]'
        }
    );
    my $diff = $args->{options}->{diff} // 0.01;
    my $min  = $args->{options}->{min} // 0;
    
    my $fh = $args->{in_fhs}->[0];
    my $matrix = load_matrix $fh;
    my @tissues = @{$matrix->[0]};
    for (my $i = 1; $i <= $#{$matrix}; $i++){
        my @array = @{$matrix->[$i]};
        my $gene_id = $array[0];
        my @index = sort{$array[$b] <=> $array[$a]}(1..$#array);
        my $best_nfpkm = $array[$index[0]];
        my $best_tissue = $tissues[$index[0]];
        my $second_nfpkm = $array[$index[1]];
        next unless $best_nfpkm - $second_nfpkm > $diff;
        next unless $best_nfpkm > $min;
        print join("\t", $gene_id, 
                         $best_tissue, 
                         $best_nfpkm, 
                         $second_nfpkm)."\n";
    }
    
}

sub unexpressed{
    my $args = new_action(
        -desc => 'List unexpressed genes'
    );
    
    my @infiles = @{$args->{infiles}};
    my @in_fhs = @{$args->{in_fhs}};
    
    for(my $i = 0; $i < scalar(@infiles); $i++){
        my $infile = $infiles[$i];
        my $in_fh = $in_fhs[$i];
        my $matrix = load_matrix $in_fh;
        for(my $j = 1; $j < scalar(@$matrix); $j++){
            my @array = @{$matrix->[$j]};
            my $geneid = $array[0];
            my $is_unexpressed = 1;
            for(my $k = 1; $k < scalar(@array); $k++){
                my $nfpkm = $array[$k];
                if($nfpkm > -2){
                    $is_unexpressed = 0;
                    last;
                }
            }
            if($is_unexpressed){
                print "$infile\t$geneid\n";
            }
        }
    }
}

sub matrix2list{
    my $args = new_action(
        -desc => 'convert a matrix to a 2-column list'
    );
    
    my @infiles = @{$args->{infiles}};
    my @in_fhs = @{$args->{in_fhs}};
    
    for (my $i = 0; $i < scalar(@infiles); $i++){
        my $infile = $infiles[$i];
        my $in_fh = $in_fhs[$i];
        my $matrix = load_matrix $in_fh;
        my @title = @{$matrix->[0]};
        for (my $j = 1; $j < scalar(@$matrix); $j++){
            my @array = @{$matrix->[$j]};
            my $geneid = $array[0];
            for(my $k = 1; $k < scalar(@array); $k++){
                my $tissue = $title[$k];
                my $nfpkm = $array[$k];
                print "$infile\t$geneid\t$tissue\t$nfpkm\n";
            }
        }
    }
    
}

__END__

