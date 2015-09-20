#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::Config;
use Text::Wrap;
local $Text::Wrap::columns = $GFAT::Config::seqwidth + 1;

sub usage{
    print <<USAGE;

perl randseq.pl [OPTIONS]

  -n,--num NUM    
     Number of sequences [default: 1]

  -m,--mode MODE  
    Mode: nt|aa|cds, nucleotide sequences, amino acid sequences 
                     or CDS [default nucleotide sequences]

  -p,--prefix STR 
    Prefix of sequence names [default: RandSeq]

  -I,--min NUM 
  -X,--max NUM 
    Minimum and maximum length of sequence [both default:100]

  -V,--version
    Print version

  -h,--help
    Print help

USAGE
    exit;
}

sub get_options{
    my $version;
    my $help;
    my $num = 1;
    my $prefix = q/RandSeq/;
    my $min = 100;
    my $max = 100;
    my $mode = q/nt/;
    GetOptions(
        "n|num=i"    => \$num,
        "p|prefix=s" => \$prefix,
        "I|min=i"    => \$min,
        "X|max=i"    => \$max,
        "m|mode=s"   => \$mode,
        "V|version"  => \$version,
        "h|help"     => \$help);
    print_version if $version;
    usage if $help;
    die "ERROR: max length ($max), min length($min)\n" if $max < $min;
    my @modes = qw/nt cds aa/;
    my %modes = map{$_, 1}@modes;
    die "Undefined modes: $mode!\n" unless $modes{$mode};
    return {
        num    => $num,
        prefix => $prefix,
        min    => $min,
        max    => $max,
        mode   => $mode,
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

sub get_unit_and_char{
    my $mode = shift;
    if($mode eq q/aa/){
        return amino_acid
    }elsif($mode eq q/cds/){
        return non_stop_codon;
    }elsif($mode eq q/nt/){
        return nucleotide;
    }else{die}
}

sub get_seqstr{
    my ($mode, $length, @char) = @_;
    my $seqstr    = rand_seq($mode eq 'cds' ? $length - 2 : $length, @char);
    $seqstr = 'ATG'.$seqstr.rand_seq(1,stop_codon) if $mode eq 'cds';
    $seqstr = wrap('', '', $seqstr);
    return $seqstr;
}

sub main{
    my $options = get_options;
    my $num = $options->{num};
    my $min = $options->{min};
    my $max = $options->{max};
    my $mode = $options->{mode};
    my $prefix = $options->{prefix};
    my ($unit, @char) = get_unit_and_char($mode);

    for my $n (1..$num){
        my $length = rand_length($min, $max);
        my $seqheader = qq/$prefix$n $length$unit/;
        my $seqstr = get_seqstr($mode, $length, @char);
        print ">$seqheader\n$seqstr\n";
    }
}

main() unless caller;
