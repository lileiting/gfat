#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use FormatSeqStr;

sub usage{
    print <<USAGE;

perl randseq.pl [OPTIONS]

  Default print nuleotide sequences 100 bp

  -n,--num     Number of sequences [default: 1]
  -a,--aa      Print amino acid sequences [default print nucleotides]
  -p,--prefix  Prefix of sequence names [default: RandSeq]
  -I,--min NUM Minimum length of sequence [defalt:100] 
  -X,--max NUM Maximum length of sequence [defalt:100]
  -h,--help    Print help

USAGE
    exit;
}

sub read_commands{
    my $help;
    my $num = 1;
    my $aa;
    my $prefix = q/RandSeq/;
    my $min = 100;
    my $max = 100;
    my $cds;
    GetOptions(
        "n|num=i"    => \$num,
        "a|aa"       => \$aa,
        "p|prefix=s" => \$prefix,
        "I|min=i"    => \$min,
        "X|max=i"    => \$max,
        "cds"        => \$cds,
        "h|help"     => \$help);
    usage if $help;
    die "ERROR: max length ($max), min length($min)\n" if $max < $min;
    die "CAUTION: CDS and AA were both switched on!" if $cds and $aa;
    return {
        num    => $num,
        prefix => $prefix,
        min    => $min,
        max    => $max,
        aa     => $aa,
        cds    => $cds
    };
}

sub nucleotide{
    return qw/bp A T G C/;
}

sub amino_acid{
    return qw/aa 
        A R N D C 
        Q E G H I 
        L K M F P 
        S T W Y V/;
}

sub non_stop_codon{
    return qw/codons
        AAA    AAT    AAG    AAC
        ATA    ATT    ATG    ATC
        AGA    AGT    AGG    AGC
        ACA    ACT    ACG    ACC
               TAT           TAC
        TTA    TTT    TTG    TTC
               TGT    TGG    TGC
        TCA    TCT    TCG    TCC
        GAA    GAT    GAG    GAC
        GTA    GTT    GTG    GTC
        GGA    GGT    GGG    GGC
        GCA    GCT    GCG    GCC
        CAA    CAT    CAG    CAC
        CTA    CTT    CTG    CTC
        CGA    CGT    CGG    CGC
        CCA    CCT    CCG    CCC
/;
}

sub stop_codon{
    return qw/TAA TAG TGA/;
}

sub rand_length{
    my ($min, $max) = @_;
    my $length;
    if($min == $max){
        $length = $min;
    }else{
        $length = $min + int(rand($max - $min + 1));
    }
    return $length;
}

sub rand_seq{
    my ($length, @char) = @_;
    return join('', map{$char[int(rand(scalar(@char)))]}(1..$length));
}

sub main{
    my $para = read_commands;
    my $num = $para->{num};
    #my $length = $para->{seqlen};
    my $min = $para->{min};
    my $max = $para->{max};
    my $aa = $para->{aa};
    my $cds = $para->{cds};
    my $prefix = $para->{prefix};
    my ($unit, @char);
    if($aa){
        ($unit, @char) = amino_acid
    }elsif($cds){
        ($unit, @char) = non_stop_codon;
    }else{
        ($unit, @char) = nucleotide;
    }

    for my $n (1..$num){
        my $length = rand_length($min, $max);
        my $seqheader = qq/$prefix$n $length$unit/;
        my $seqstr    = rand_seq( $cds ? $length - 2 : $length, @char);
        $seqstr = 'ATG'.$seqstr.rand_seq(1,stop_codon) if $cds;
        $seqstr = format_seqstr($seqstr);
        print ">$seqheader\n$seqstr\n";
    }
}

main;
