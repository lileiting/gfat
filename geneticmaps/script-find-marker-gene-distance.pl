#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw/min/;

sub main_usage{
    print <<";;;";

USAGE
    $FindBin::Script <GFF> <blast.best> <isPcr.bed.best>

;;;
    exit;
}

sub main{
    main_usage unless @ARGV == 3;
    my ($gff_file, $blast_file, $isPcr_file) = @ARGV;

    my %markers;
    open my $blast_fh, $blast_file or die "$!: $blast_file\n";
    while(<$blast_fh>){
        next if /^\s*$/ or /^\s*#/;
        chomp;
        my($marker, $chr, $start, $end) = (split /\t/)[0,1,8,9];
        $markers{$marker} = [$chr, $start, $end, 'SNP'];
    }
    close $blast_fh;

    open my $isPcr_fh, $isPcr_file or die "$!: $isPcr_file\n";
    while(<$isPcr_fh>){
        next if /^\s*$/ or /^\s*#/;
        chomp;
        my ($chr, $start, $end, $marker) = split /\t/;
        $markers{$marker} = [$chr, $start, $end, 'SSR'];
    }
    close $isPcr_fh;

    my %gff;
    open my $gff_fh, $gff_file or die "$!: $gff_file\n";
    while(<$gff_fh>){
        next if /^\s*$/ or /^\s*#/;
        chomp;
        my ($chr, $type, $start, $end, $ann) = (split /\t/)[0,2,3,4,8];
        next unless $type eq 'mRNA';
        my @array = split /;/, $ann;
        my %hash;
        map {my ($key, $value) = split /=/; $hash{$key} = $value} @array;
        die "WARNING! 'ID=' is expected in $ann" unless $hash{ID};
        my $geneid = $hash{ID};
        push @{$gff{$chr}}, [$geneid, $start, $end];
    }
    close $gff_fh;

    for my $marker (keys %markers){
        my ($chr, $start, $end, $type) = @{$markers{$marker}};
        my %distance;
        for my $ref (@{$gff{$chr}}){
            my ($geneid, $gene_start, $gene_end) = @$ref;
            my $distance = resolve_distance([$start, $end],
                [$gene_start, $gene_end]);
            $distance{$geneid} = $distance;
        }
        my @geneids = sort {$distance{$a} <=> $distance{$b}} keys %distance;
        my $closest_gene = $geneids[0] // "NA";
        my $distance = $distance{$closest_gene} // "NA";
        die "$marker: $closest_gene\n" if $distance eq '';
        print join("\t",$marker, $chr, $start, $end, $type,
            $closest_gene, $distance)."\n";
    }
}

sub resolve_distance{
    my ($ref1, $ref2) = @_;
    my ($n1, $n2) = sort {$a <=> $b} @$ref1;
    my ($m1, $m2) = sort {$a <=> $b} @$ref2;
    if($n2 < $m1){
        return $m1 - $n2;
    }
    elsif($n1 > $m2){
        return $n1 - $m2;
    }
    else{
        return 0;
    }
}

main unless caller;
