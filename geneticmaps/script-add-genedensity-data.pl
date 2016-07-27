#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub main_usage{
    print <<";;;";

USAGE
    $FindBin::Script <closest-gene> <density-200000> <density-500000> <density-1000000>

;;;
    exit;
}

sub main{
    main_usage unless @ARGV == 4;
    my @files = @ARGV;
    my %density;
    for my $i (1..3){
        open my $fh, $files[$i] or die;
        while(<$fh>){
            chomp;
            my ($chr, $pos, $num_genes) = split /\t/;
            $density{$i}->{$chr}->{$pos} = $num_genes;
        }
        close $fh;
    }
    open my $fh, $files[0] or die;
    while(<$fh>){
        chomp;
        my ($marker, $chr, $start, $end, $type, $gene, $distance) = split /\t/;
        my @window;
        for my $window (200_000, 500_000, 1_000_000){
            my $middle = sprintf "%f", ($start + $end) / 2;
            push @window, int($middle / $window + 1) * $window / 1_000_000;
        }
        print join("\t", $marker, $chr, $start, $end, $type, $gene, $distance);
        for my $i (1..3){
            print "\t", $window[$i-1] // 'NA';
            print "\t", $density{$i}->{$chr}->{$window[$i-1]} // 'NA';
        }
        print "\n";
    }
    close $fh;

}

main unless caller;
