#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub main_usage{
    print <<";;;";

USAGE
    $FindBin::RealScript <snp.txt> <GFF>

;;;
    exit;
}

sub main{
    main_usage unless @ARGV;
    my ($snp_file, $gff_file) = @ARGV;

    my %gff;
    my %chr;
    open my $gff_fh, $gff_file or die;
    while(<$gff_fh>){
        next if /^\s*$/ or /^\s*#/;
        my ($chr, $type, $start, $end, $ann) = (split /\t/)[0,2,3,4,8];
        next unless $type eq 'mRNA';
        my @array = split /;/, $ann;
        my %hash;
        map {my ($key, $value) = split /=/; $hash{$key} = $value} @array;
        die "WARNING! 'ID=' is expected in $ann" unless $hash{ID};
        my $geneid = $hash{ID};
        push @{$chr{$chr}},[$geneid,$start, $end];
        $gff{$geneid} = [$chr, $start, $end];
    }
    close $gff_fh;

    open my $snp_fh, $snp_file or die;
    while(<$snp_fh>){
        chomp;
        my ($marker, $scaffold, $pos) = split /\t/;
        warn "$scaffold was not found in GFF file\n"
            unless exists $chr{$scaffold};
        for (@{$chr{$scaffold}}){
            my ($geneid, $start, $end) = @$_;
            if(abs($start - $pos) < 200_000 or abs($end - $pos) < 200_000){
                print join("\t", $marker, $scaffold, $pos,
                    $geneid,$start, $end
                )."\n";
            }
        }
    }
    close $snp_fh
}

main unless caller;

__END__
