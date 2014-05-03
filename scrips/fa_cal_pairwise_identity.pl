#!/usr/bin/env perl

use warnings;
use strict;
use Bio::Perl;
use Bio::AlignIO;
use File::Basename;

die "Usage: ",basename($0)," <FASTA> [<FASTA> ...] [-pair]\n" unless @ARGV;

###############
if($ARGV[-1] eq '-pair'){
	pop @ARGV;
	die "Usage: ", basename($0)," <FASTA> <FASTA> -pair\n" unless @ARGV == 2;

	&print_input_info(@ARGV);

	my @seq0 = read_all_sequences($ARGV[0], 'fasta');
       	my @seq1  = read_all_sequences($ARGV[1], 'fasta');
        for my $seq1 (@seq0){
                for my $seq2 (@seq1){
                        &cal_identity($seq1, $seq2);
                }
        }
	exit;
}else{
	&print_input_info(@ARGV);

	my @seq_all;
	map{push @seq_all, read_all_sequences($_, 'fasta')}@ARGV;

	for(my $i=0; $i <= $#seq_all - 1; $i++){
		for(my $j = $i + 1; $j <= $#seq_all; $j++){
			&cal_identity($seq_all[$i], $seq_all[$j]);
		}
	}
}

##############
# Subroutine #
##############

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
	system("muscle -in $tmp_file -out $tmp_pre.aln -clw -clwstrict 2>/dev/null >/dev/null");
	my $alignio = Bio::AlignIO->new(-format => 'clustalw',
                              		-file => "$tmp_pre.aln");
	unlink $tmp_file,"$tmp_pre.aln","$tmp_pre.dnd";
	my $aln = $alignio->next_aln;
	print $seq1->display_id,"\t",
		$seq2->display_id, "\t", 
		$aln->percentage_identity,"\n";
	
}
