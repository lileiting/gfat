#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use Getopt::Long;

sub usage{
    print <<"end_of_usage";

USAGE
    $FindBin::Script [Options] genelist1 [genelist2 ...]

Options
    -bed <bed file from isPcr>
    -blast8 <blast8 file from blat>
    -gff <gff>   
    -window NUM  [default: 100000]

end_of_usage
    exit;
}

sub main{
    usage unless @ARGV;

    my %options;
    GetOptions(
        \%options,
        "bed=s",
        "blast8=s",
        "gff=s",
        "window=i"
    );
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

    die "Hey!  Markers info empty!" unless keys %markers;

    my %gff;
    if($options{gff}){
        warn "Loading data from $options{gff} ...\n";
        open my $fh, $options{gff} or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            my ($chr, $type, $start, $end, $ann) = (split /\t/)[0,2,3,4,8];
            next unless $type eq 'mRNA';
            die "Hey! Which is gene ID? $ann" unless $ann =~ /ID=([\w\.]+)/;
            my $geneid = $1;
            $gff{$geneid} = [$chr, $start, $end];
        }
        close $fh;
    }

    die "Hey! GFF info empty!" unless keys %gff;

    for my $file (@ARGV){
        warn "Process gene list file $file ...\n";
        open my $fh, $file or die $!;
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            chomp;
            my ($geneid, $genename, $genetype) = split /\t/;
            die "Hey! Gene ID $geneid was not found in the GFF file"
                unless exists $gff{$geneid};
            my ($chr, $start, $end) = @{$gff{$geneid}};
            my $markers = find_markers(
                \%markers, $options{window}, $chr, $start, $end);
            print join("\t", $file, $geneid, $genename, $genetype, $chr, $start, $end, $markers)."\n";
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

