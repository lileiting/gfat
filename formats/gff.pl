#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Formats::Cmd::Base qw(get_fh close_fh);

sub usage{
    print <<USAGE;

  $FindBin::Script CMD <GFF>

  Commands:
    chrlist   | Print chromosome list   
    genelist  | Print gene list
    exonnum   | Print exon number for each gene
    intronnum | Print intron number for each gene

    geneinfo  | Print gene information, including gene
                name, exon number, intron number, etc

    type      | Print the number of entries for each type

USAGE
   exit;
}

sub get_functions{
    return (
        chrlist   => \&print_chromosome_list, 
        genelist  => \&print_gene_list,
        exonnum   => \&print_exon_number,
        intronnum => \&print_intron_number,
        geneinfo  => \&print_gene_information,
        type      => \&print_type_number,
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

# 
# Print by chromosome
# 

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

#
# Print by gene
#

sub number_of_exons{
    my ($data, $gene) = @_;
    return scalar(@{$data->{$gene}->{CDS}});
}

sub number_of_introns{ return number_of_exons(@_) - 1; }

sub print_gene_information{
    my $cmd = shift // '';
    my ($in_fh, $out_fh) = get_fh($cmd);
    my $data = load_gff_file($in_fh);
    for my $gene (sort {by_number($a) <=> by_number($b)} keys %$data){
        if($cmd eq q/genelist/){
            print "$gene\n";
        }elsif($cmd eq q/exonnum/){
            my $exon_number = number_of_exons($data,$gene);
            print $out_fh "$gene\t$exon_number\n";
        }elsif($cmd eq q/intronnum/){
            my $intron_number = number_of_introns($data, $gene);
            print $out_fh "$gene\t$intron_number\n";
        }else{
            my $exon_number = number_of_exons($data,$gene);
            my $intron_number = number_of_introns($data, $gene);
            print $out_fh "$gene\t$exon_number\t$intron_number\n";
        }
    }
    close_fh($in_fh, $out_fh);
}

sub print_gene_list          { print_gene_information(q/genelist/ ) }
sub print_exon_number        { print_gene_information(q/exonnum/  ) }
sub print_intron_number      { print_gene_information(q/intronnum/) }

#
# Print by type
#

sub print_type_number{
    my ($in_fh, $out_fh) = get_fh(q/type/);
    my $data = load_gff_file($in_fh);
    my %types;
    for my $gene (sort {$a cmp $b} keys %$data){
        for my $type (keys %{$data->{$gene}}){
             $types{$type} += scalar( @{$data->{$gene}->{$type}} );
        }
    }
    for my $type ( sort {$a cmp $b} keys %types){
        my $value = $types{$type};
        print $out_fh "$type\t$value\n";
    }
    close_fh($in_fh, $out_fh);
}


