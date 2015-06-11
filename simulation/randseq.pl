#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use FormatSeqStr;

sub usage{
    print <<USAGE;

perl randseq.pl LENGTH [OPTIONS]

  Default print nuleotide sequences 100 bp

  -n,--num    Number of sequences [default: 1]
  -a,--aa     Print amino acid sequences [default print nucleotides]
  -p,--prefix Prefix of sequence names [default: RandSeq]
  -h,--help   Print help

USAGE
    exit;
}

sub read_commands{
    my $help;
    my $num = 1;
    my $aa;
    my $seqlen = 100;
    my $prefix = q/RandSeq/;
    GetOptions(
        "n|num=i" => \$num,
        "a|aa" => \$aa,
        "p|prefix=s" => \$prefix,
        "h|help" => \$help);
    usage if $help;
    $seqlen = shift @ARGV if @ARGV;
    return {
        num => $num,
        seqlen => $seqlen,
        prefix => $prefix,
        aa => $aa
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

sub rand_seq{
    my ($length, @char) = @_;
    return join('', map{$char[int(rand(scalar(@char)))]}(1..$length));
}

sub main{
    my $para = read_commands;
    my $num = $para->{num};
    my $length = $para->{seqlen};
    my $aa = $para->{aa};
    my $prefix = $para->{prefix};
    my ($unit, @char) = nucleotide;
    ($unit, @char) = amino_acid if $aa;

    for my $n (1..$num){
        my $seqheader = qq/$prefix$n $length$unit/;
        my $seqstr    = format_seqstr(rand_seq($length, @char));
        print ">$seqheader\n$seqstr\n";
    }
}

main;
