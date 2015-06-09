#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;

sub usage{
    print <<USAGE;

perl randseq.pl LENGTH [OPTIONS]

  Default print nuleotide sequences 100 bp

  -a,--aa    print amino acid sequences
  -h,--help  print help

USAGE
    exit;
}

sub read_commands{
    my $help;
    my $aa;
    my $seqlen = 100;
    GetOptions(
        "a|aa" => \$aa,
        "h|help" => \$help);
    usage if $help;
    $seqlen = shift @ARGV if @ARGV;
    return {
        seqlen => $seqlen,
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

sub main{
    my $para = read_commands;
    my $length = $para->{seqlen};
    my $aa = $para->{aa};
    my ($unit, @char) = nucleotide;
    ($unit, @char) = amino_acid if $aa;

    print qq/>Random_Sequence_$length$unit\n/;
    my $count = 0;
    for(1..$length){
        print $char[int(rand(scalar(@char)))];
        $count++;
        print qq/\n/ if $count % 60 == 0;
    } 
    print qq/\n/ if $count % 60 != 0;
}

main;
