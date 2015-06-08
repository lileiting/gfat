#!/usr/bin/env perl

use warnings;
use strict;
use Bio::SeqIO;

unless(@ARGV == 4){
	die "Usage: $0 <seq.fa> <Seq ID> <Start pos> <End pos>\n";
}

print STDERR 
	"---------Input file: $ARGV[0]\n",
	"-------Seqquence ID: $ARGV[1]\n",
	"-----Start position: $ARGV[2]\n",
	"-------End position: $ARGV[3]\n";

my $result;
my $in = Bio::SeqIO->new(-file => $ARGV[0],
			-format => 'fasta');
while(my $seq = $in->next_seq()){
	if($seq->display_id eq $ARGV[1]){
		$result = '>'.$seq->display_id."_$ARGV[2]_$ARGV[3]\n".
			$seq->subseq($ARGV[2],$ARGV[3])."\n";
	}
}

if($result){
	print $result;
}else{
	print "Not found!\n";
}

