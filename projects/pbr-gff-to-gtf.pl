#!/usr/bin/env perl

use warnings;
use strict;

die "perl $0 <pear.gff>\n" unless @ARGV == 1;

my $infile = shift @ARGV;

my %data;
open my $fh, $infile or die "unable to open the file";
while(<$fh>){
    chomp;
    my @f = split /\t/;
    my $type = $f[2];
    if($type eq 'mRNA'){
        $f[$#f] =~ s/ID=([^;]+);/ID=$1;Name=$1;/;
        print join("\t", @f[0,1], 'gene', @f[3..$#f]), "\n";
        $f[$#f] =~ s/ID=([^;]+);/ID=$1;Parent=$1;/;
        print join("\t", @f), "\n";
    }
    elsif($type eq 'CDS' or $type =~ /utr/i){
        my %ann = map{split /=/}split /;/, $f[8];
        die unless $ann{Parent};
        $data{$ann{Parent}}++;
        my $exon_ann = sprintf "ID=%s.exon.%d;%s", $ann{Parent}, $data{$ann{Parent}}, $f[$#f];
        my $CDS_ann = sprintf "ID=%s.CDS.%d;%s", $ann{Parent}, $data{$ann{Parent}}, $f[$#f];
        print join("\t", @f[0,1], 'exon', @f[3..$#f - 1], $exon_ann), "\n";
        print join("\t", @f[0..$#f - 1], $CDS_ann), "\n";
    }
    else{
        next;
    }
}
close $fh;




