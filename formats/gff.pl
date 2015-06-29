#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Formats::Cmd::Base;

sub usage{
    print <<USAGE;

  $FindBin::Script CMD <GFF>

  Commands:
    chrlist  | Print chromosome list   
    genelist | Print gene list

USAGE
   exit; 
}

sub get_functions{
    return (
        chrlist   => \&print_chromosome_list, 
        genelist  => \&print_gene_list,
    );
}

sub main{
    usage unless @ARGV;
    my $cmd = shift @ARGV;
    my %functions = get_functions;
    $functions{$cmd} ? &{$functions{$cmd}} : 
        (warn "Undefined cmd: $cmd\n" and usage)
}

main() unless caller;

###################
# Define commands #
###################

# Data structure
# HASH => GeneID => Type(gene, mRNA, CDS, exon, etc) 
#   => [type_entry1, type_entry2, etc] X 
#      [Chr, Start, End, Strand]
# $data{Pbr01.1}->{gene}->[0]->[0] = $chr
# $data{Pbr01.1}->{mRNA}->[0]->[0] = $chr
# $data{Pbr01.1}->{CDS}->[0]->[0] = $chr

sub gff_entry{
    my $line = shift;
    my @F = split /\t/, $line;
    my ($chr, $type, $start, $end, $strand) = @F[0,2,3,4,6];
    my %info = grep{!/^\s*$/}(split /[;=]/, $F[8]);
    my $id = $info{ID} // $info{Parent} // die "Where is ID in \"$line\"";
    return (
        chr => $chr,
        type => $type,
        start => $start,
        end  => $end,
        strand => $strand,
        id => $id,
    )
}

sub load_gff_file{
    my $in_fh = shift;
    my %data; # %data => Gene ID => 
    print STDERR "Loading GFF file ...\n";
    while(<$in_fh>){
        my %entry = gff_entry($_);
        push @{$data{$entry{id}}->{$entry{type}}},
             [$entry{chr},$entry{start}, $entry{end},$entry{strand}];
    }
    return \%data;
}

sub by_number{
    my $str = shift;
    die "Where is the number in Chromosome/scaffold name: $str???" 
        unless $str =~ /^.*?(\d+(\.\d+)?)/;
    return $1;
}

sub print_chromosome_list{
    my ($in_fh, $out_fh) = get_fh(q/chrlist/);
    my $data = load_gff_file($in_fh);
    my %chromosome;
    for my $key (keys %$data){
        my $chr = $data->{$key}->{mRNA}->[0][0];
        $chromosome{$chr}++;
    }
    for my $chr (sort {by_number($a) <=> by_number($b)} keys %chromosome){
        print $out_fh "$chr\n";
    }
    close_fh($in_fh, $out_fh);
}

sub print_gene_list{
    my ($in_fh, $out_fh) = get_fh(q/chrlist/);
    my $data = load_gff_file($in_fh);
    my %genes;
    for my $gene (sort {by_number($a) <=> by_number($b)} keys %$data){
        print "$gene\n";
    }
    close_fh($in_fh, $out_fh);
}

