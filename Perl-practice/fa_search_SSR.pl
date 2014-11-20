#!/usr/bin/env perl

use warnings;
use strict;
use Bio::Perl;

# Date: Apr 26, 2012
# Defination of SSR:
# Repeat unit 2bp to 6bp, length not less than 18bp

$flank_seq_length=100;

unless(@ARGV==1){
	die "Usage: $0 <Input_Fasta_File>\n";
}

my @seq=read_all_sequences($ARGV[0],'fasta');

print "ID\tSeq_Name\tStart\tEnd\tSSR\tLength\tRepeat_Unit\tRepeat_Unit_Length\tRepeatitions\tSequence\n";
my $id;
for my $seq (@seq){
	$seq_name = $seq->display_id;
	&search_SSR($seq->seq);
}

sub search_SSR($){
	my $sequence=shift;
	while($sequence =~ /(([ATGC]{2,6}?)\2{3,})/g){
		my $match=$1;
		my $repeat_unit=$2;
                my $repeat_length=length($repeat_unit);
                my $SSR_length=length($match);
		next unless $SSR_length >= 18;
		if($match =~ /([ATGC])\1{5}/){next;}
		$id++;
		print 	"$id\t$seq_name\t",
		 	pos($sequence)-$SSR_length+1,"\t",
			pos($sequence),"\t",
			$match,"\t",
			$SSR_length,"\t",
			$repeat_unit,"\t",
			$repeat_length,"\t",
			$SSR_length / $repeat_length,"\t",
			substr($sequence,pos($sequence)-$SSR_length-$flank_seq_length,$flank_seq_length+$SSR_length+$flank_seq_length),
			"\n";
	}
}

