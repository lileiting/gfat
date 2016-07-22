#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use Getopt::Long;

sub main_usage{
    print <<"usage";

USAGE

    $FindBin::Script <gff> <in.fasta>

DESCRIPTION

    This script will extract chromosome, start position, end
    position and ID information from GFF file, and create a
    hash array to map old IDs in input fasta file to new IDs.
    The old ID format is like chr:start-end, where
    start_in_fasta = start_in_gff - 1, and new ID is the ID
    key in gff file. If there was no ID information in a GFF
    line, that line would be ignored.

    Comments start with # and blank lines would be ignored
    before processing.

    Output file would be writen to a new file <in.fasta>.out

OPTIONS

    -d,--desc,--description
        Print old IDs as description in new sequence
        default: no

    -h,--help
        Print this usage

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $help;
    my $desc;
    GetOptions("description|desc|d" => \$desc,
               "help|h" => \$help);
    main_usage if $help;
    main_usage unless @ARGV == 2;

    my ($gff_file, $infasta) = @ARGV;
    my %id_map = load_gff($gff_file);
    my $newfile = "$infasta.out";
    warn "Writing ID converted sequences to file: $newfile ...\n";
    open my $out_fh, ">$newfile" or die $!;
    open my $in_fh, $infasta or die;
    while(<$in_fh>){
        if(/^>(\S+)/){
            my $old_id = $1;
            die "CAUTION: no corresponding ID for $old_id!!!"
                unless $id_map{$old_id};
            print $out_fh ">", $id_map{$old_id},
                             $desc ? " $old_id" : "",
                              "\n";
        }
        else{
            print $out_fh $_;
        }
    }
    close $in_fh;
}

main() unless caller;

############################################################

sub find_id_in_feature{
    my $feature = shift;
    my @pairs = split /;/, $feature;
    my %hash;
    for my $pair (@pairs){
        my ($key, $value) = split /=/, $pair;
        $hash{$key} = $value;
    }
    if(exists $hash{ID}){
        return $hash{ID};
    }
    elsif(exists $hash{Parent}){
        return $hash{Parent};
    }
    else{
        return undef;
    }
}

sub load_gff{
    my $gff_file = shift;
    my %id_map;
    open my $fh, $gff_file or die $!;
    while(<$fh>){
        next if /^\s*$/ or /^\s*#/;
        chomp;
        @_ = split /\t/;
        my $chr = $_[0];
        my $start = $_[3];
        my $end = $_[4];
        my $feature = $_[8];
        my $id = find_id_in_feature($feature);
        next unless defined $id;
        my $bed_seqid = sprintf "%s:%d-%d", $chr, $start - 1, $end;
        $id_map{$bed_seqid} = $id;
    }
    close $fh;
    return %id_map;
}

__END__
Leiting Li, 2015/12/2
Updated 2016/1/8
