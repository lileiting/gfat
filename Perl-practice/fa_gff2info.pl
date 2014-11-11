#!/usr/bin/perl

use warnings;
use strict;

die "Usage: perl $0 <GFF>

Convert gff to a gene information as 
Gene_ID\tChromosome\tLength_of_gene\tNo_of_exons\tAvg_exons\tAvg_introns
" unless @ARGV == 1;

my %gene_list;
my $gff_file = shift @ARGV;

print STDERR "Loading GFF file ...\n";
my %info;
open my $gff_fh, $gff_file or die;
while(my $stream = <$gff_fh>){
	chomp($stream);
	my @txt = split /\t/,$stream;
	my @ann = split /;/,$txt[8];
	my %ann;
	map{@_ = split /=/,$_; $ann{$_[0]} = $_[1]}@ann;

	delete $ann{'ID'} if $txt[2] eq 'CDS';
	$gene_list{$ann{'ID'}}++ if $txt[2] eq 'mRNA';

	if($ann{'ID'}){ # mRNA
		$info{$ann{'ID'}}->{'chr'} = $txt[0]; 
		$info{$ann{'ID'}}->{'typ'} = $txt[2];
		$info{$ann{'ID'}}->{'sta'} = $txt[3];
		$info{$ann{'ID'}}->{'end'} = $txt[4];
		$info{$ann{'ID'}}->{'str'} = $txt[6];
	}elsif($ann{'Parent'}){ # UTR or CDS
		$info{$ann{'Parent'}}->{'count'}->{$txt[2]}++; # No. of CDSs
		
		$info{$ann{'Parent'}}->{$txt[2]}->{ 
			$info{$ann{'Parent'}}->{'count'}->{$txt[2]}
			}->{'sta'} = $txt[3]; # CDS -> start
		$info{$ann{'Parent'}}->{$txt[2]}->{
                        $info{$ann{'Parent'}}->{'count'}->{$txt[2]}
                        }->{'end'} = $txt[4]; # CDS -> end
		$info{$ann{'Parent'}}->{$txt[2]}->{
                        $info{$ann{'Parent'}}->{'count'}->{$txt[2]}
                        }->{'pha'} = $txt[7]; # CDS -> phase
	}else{die}
}
close $gff_fh;

my @lst = (keys %gene_list);

print STDERR "Output gene information ...\n";
print "#------------------------------------------------------------------------------------------
#Gene_ID\tChromosome\tLength_of_gene\tNo_of_exons\tAvg_exons\tAvg_introns
#------------------------------------------------------------------------------------------
";
for my $id (sort {$a cmp $b} @lst){
	my $len_exons;
	my %hash;

	for my $element (qw/CDS UTR_5 UTR_3/){
		if($info{$id}->{$element}){
			$hash{$element} = [keys %{$info{$id}->{$element}}];
		}
	}

	my $no_of_exons = $info{$id}->{'count'}->{'CDS'};
	die "ID: $id\n" unless $no_of_exons;

	my @border;
	for my $element (keys %hash){
		for my $i (@{$hash{$element}}){

			$len_exons += $info{$id}->{$element}->{$i}->{'end'} 
					- $info{$id}->{$element}->{$i}->{'sta'} + 1;
			push @border, 
				$info{$id}->{$element}->{$i}->{'end'}, 
				$info{$id}->{$element}->{$i}->{'sta'};
		}
	}
	my $avg_exon = $len_exons / $no_of_exons;

	my($cds_start,$cds_end) = (sort {$a <=> $b} @border)[0,-1];
	my $avg_intron;
	if($no_of_exons > 1){
		$avg_intron = ($cds_end - $cds_start + 1 - $len_exons) 
				/ ($no_of_exons - 1) ; # No. of introns
	}else{
		$avg_intron = 0;
	}

	printf 	"%s\t%s\t%d\t%d\t%.1f\t%.1f\n",
		$id,
		$info{$id}->{'chr'},
		$info{$id}->{'end'} - $info{$id}->{'sta'} + 1,
		$no_of_exons, # No. of CDSs
		$avg_exon, 
		$avg_intron;
}
