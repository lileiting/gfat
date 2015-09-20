#!/usr/bin/env perl

use warnings;
use strict;
use Bio::Perl;
use Bio::AlignIO;
use File::Basename;
use Getopt::Long;
use FindBin;

sub usage{
    print <<"usage";

USAGE
    $FindBin::Script [OPTIONS] <FASTA> [<FASTA> ...]

OPTIONS
    -help|?     Print usage
    -p          Two files are required, and only compare 
                sequences between two files

usage
    exit;
}

sub main{
    my ($help, $pair);
    GetOptions ("help|?" => \$help,
                "pair"   => \$pair);
    &usage if $help or @ARGV == 0 or ($pair and @ARGV != 2);
    if($pair){&mode1}else{&mode2}
    exit;
}

main unless caller;

###############
# Subroutines #
###############

sub mode1{
    &print_input_info(@ARGV);
    my @seq0 = read_all_sequences($ARGV[0], 'fasta');
    my @seq1 = read_all_sequences($ARGV[1], 'fasta');
    for my $seq1 (@seq0){
        for my $seq2 (@seq1){
            &cal_identity($seq1, $seq2);
        }
    }
}

sub mode2{
    &print_input_info(@ARGV);
    my @seq_all;
    map{push @seq_all, read_all_sequences($_, 'fasta')}@ARGV;
    for(my $i=0; $i <= $#seq_all - 1; $i++){
        for(my $j = $i + 1; $j <= $#seq_all; $j++){
            &cal_identity($seq_all[$i], $seq_all[$j]);
        }
    }
}

sub print_input_info{
    my @files = @_;
    my @seq_all;
    map{push @seq_all, read_all_sequences($_, 'fasta')}@files;

    my $i;
    print STDERR "-" x 60, "\n";
    map{print STDERR "Input file: $_\n"}@files;
    print STDERR "-" x 60, "\n";
    for(@seq_all){
        $i++;
        print STDERR "$i: ",$_->display_id,"\t", $_->length, "\n";
    }
    print STDERR "-"x60, "\n";
}

sub cal_identity{
    my ($seq1, $seq2) = @_;
    my $tmp_pre = "/tmp/tmp".time.rand(1);
    my $tmp_file = $tmp_pre.".fasta";
    write_sequence(">$tmp_file", 'fasta', $seq1, $seq2);
    system("clustalw2 -INFILE=$tmp_file -ALIGN 2>/dev/null >/dev/null");
    #system("muscle -in $tmp_file -out $tmp_pre.aln -clw -clwstrict 2>/dev/null >/dev/null");
    my $alignio = Bio::AlignIO->new(-format => 'clustalw',
                                      -file => "$tmp_pre.aln");
    unlink $tmp_file,"$tmp_pre.aln","$tmp_pre.dnd";
    my $aln = $alignio->next_aln;
    print $seq1->display_id,"\t",
        $seq2->display_id, "\t", 
        sprintf("%.1f",$aln->percentage_identity),"\n";
}
