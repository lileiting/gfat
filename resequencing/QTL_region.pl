#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use Getopt::Long;

sub usage{
    print <<"end_of_usage";

USAGE
    $FindBin::Script
        {-bed <bed>|-blast8 <blast8>} -gff <gff>
        [-window NUM] genelist1 [genelist2 ...]

DESCRIPTION
    This script is used to find out whether a list of genes
    was close to given QTL regions. QTL regions were
    defined by the mapped positions of SSR/SNP markers on
    chromosome/scaffold sequences. Chromosome/scaffold
    location of given genes were defined by a given GFF
    format file.

OPTIONS
    -bed <bed>
        Use isPcr program to map SSR markers to reference
        genome, and then use "gfat.pl formats bed isPcr"
        command to get the best isPcr hit per query

    -blast8 <blast8>
        Use blat program to map SNP flanking sequences to
        reference genome, and then use
        "python -m jcvi.formats.blast best" command to get
        the best BLAST hit per query

    -gff <gff>
        This script expects gene ID in 'mRNA' type line
        with identifier "ID="

    -window NUM
        Unit: bp [default: 100000]

end_of_usage
    exit;
}

sub main{
    my %options;
    GetOptions(
        \%options,
        "bed=s",
        "blast8=s",
        "gff=s",
        "window=i"
    );
    usage unless @ARGV;

    $options{window} //= 100_000;

    my %markers;
    if($options{bed}){
        warn "Loading data from $options{bed} ...\n";
        open my $fh, $options{bed} or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            my ($chr, $start, $end, $marker) = split /\t/;
            $markers{$marker} = [$chr, $start, $end];
        }
        close $fh;
    }

    if($options{blast8}){
        warn "Loading data from $options{blast8} ...\n";
        open my $fh, $options{blast8} or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            my($marker, $chr, $start, $end) = (split /\t/)[0,1,8,9];
            $markers{$marker} = [$chr,$start, $end];
        }
        close $fh;
    }

    die "WARNING! Bed file and blast8 files are both missing!" unless keys %markers;

    my %gff;
    if($options{gff}){
        warn "Loading data from $options{gff} ...\n";
        open my $fh, $options{gff} or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            my ($chr, $type, $start, $end, $ann) = (split /\t/)[0,2,3,4,8];
            next unless $type eq 'mRNA';
            my @array = split /;/, $ann;
            my %hash;
            map {my ($key, $value) = split /=/; $hash{$key} = $value} @array;
            die "WARNING! 'ID=' is expected in $ann" unless $hash{ID};
            my $geneid = $hash{ID};
            $gff{$geneid} = [$chr, $start, $end];
        }
        close $fh;
    }

    die "WARNING! GFF file is missing!" unless keys %gff;

    for my $file (@ARGV){
        warn "Process gene list file $file ...\n";
        open my $fh, $file or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            chomp;
            my ($geneid) = split /\t/;
            die "Hey! Gene ID $geneid was not found in the GFF file"
                unless exists $gff{$geneid};
            my ($chr, $start, $end) = @{$gff{$geneid}};
            my $markers = find_markers(
                \%markers, $options{window}, $chr, $start, $end);
            print join("\t", $file, $_, $chr, $start, $end, $markers)."\n";
        }
        close $fh;
    }
}

main unless caller;

sub find_markers{
    my ($markers, $window, $chr, $start, $end) = @_;
    my @markers;
    for my $marker (keys %{$markers}){
        my ($marker_chr, $marker_start, $marker_end) = 
            @{$markers->{$marker}};
        next unless $chr eq $marker_chr;
        my $middle = ($start + $end) / 2;
        my $marker_middle = ($marker_start + $marker_end) / 2;
        push @markers, $marker if abs($middle - $marker_middle) <= $window;
    }
    
    return scalar(@markers)."\t".(@markers ? join(",", @markers) : 'NA');
}

__END__

