#!/usr/bin/env perl

use warnings;
use strict;
#use Bio::Perl;
use Bio::DB::Fasta;
#use Getopt::Long;
use File::Basename;

die "Usage: ", basename($0), " <GFF> <FASTA>\n" unless @ARGV == 2;

my ($gff_file, $chr_file) = @ARGV;
my $db = Bio::DB::Fasta->new($chr_file);

open my $fh, "<", $gff_file or die "$gff_file:$!";
while(<$fh>){
	next if /^\s*#/ or /^\s*$/;
	my($chr,undef,$type,$start, $end,undef, $strand,undef,$ann) = split /\t/;
	next unless $type eq 'mRNA';
	my @ann = grep {!/^\s*$/} (split /;/,$ann);
	my %hash;
	map{@_ = split /=/;$hash{$_[0]} = $_[1]}@ann;
	die "ERROR: No gene ID! ... $ann\n" unless $hash{'ID'};
	my $seqstr;
	if($strand eq '+'){
		$seqstr = $db->seq($chr, $start => $end);
	}elsif($strand eq '-'){
		$seqstr = $db->seq($chr, $end => $start);
	}else{die}
	$seqstr =~ s/(.{60})/$1\n/g;
	print ">",$hash{'ID'}, 
		" $chr:$start-$end|", $end - $start + 1, 
		"bp|$strand\n$seqstr\n";
}
close $fh;
