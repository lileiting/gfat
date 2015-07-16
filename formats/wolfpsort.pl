#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;

sub usage{
    print <<usage;

USAGE
  $FindBin::Script [OPTIONS] <WoLFPSORT.results.txt>

DESCRIPTION
  Processing results from WoLFPSORT.
  To run WoLFPSORT in command line: 
    runWolfPsortSummaryOnly.pl plant < Query.fasta

OPTIONS
  [-i,--input]  FILE
  -o,--output   FILE
  -h,--help

usage
    exit;
}

sub get_input_fh{
    my $file = shift;
    my $fh;
    if($file){
        open $fh, "<", $file or die "$file:$!";
    }else{
        $fh = \*STDIN;
    }
    return $fh;
}

sub get_output_fh{
    my $file = shift;
    my $fh;
    if($file){
        open $fh, ">", $file or die "$file:$!";
    }else{
        $fh = \*STDOUT;
    }
    return $fh;
}

sub get_options{
    my %options;
    GetOptions(
        "input=s" => \$options{input},
        "output=s" => \$options{output},
        "help"   => \$options{help}
    );
    usage if $options{help};
    usage if not $options{input} and @ARGV == 0 and -t STDIN;
    $options{input} = shift @ARGV if @ARGV > 0 and not $options{input};
    $options{in_fh} = get_input_fh($options{input});
    $options{out_fh} = get_output_fh($options{output});
    return \%options;
}

sub resolve_abbr{
    my $abbr = shift;
    my %scl_abbr = (
        "E.R."       => "Endoplasmic Reticulum",
        chlo       => "Chloroplast",
        chlo_mito  => "Chloroplast/Mitochondria",
        cysk       => "Cytoskeleton",
        cyto       => "Cytosol",
        cyto_nucl  => "Cytosol/Nucleus",
        extr       => "Extracellular",
        golg       => "Golgi Apparatus",
        golg_plas  => "Golgi Apparatus/Plasma Membrane",
        mito       => "Mitochondria",
        nucl       => "Nucleus",
        nucl_plas  => "Nucleus/Plasma Membrane",
        pero       => "Peroxisome",
        plas       => "Plasma Membrane",
        vacu       => "Vacuolar Membrane"
    );
    if($scl_abbr{$abbr}){
        return $scl_abbr{$abbr};
    }else{
        return $abbr;
    }
}

sub process_wolfpsort{
    my $options = shift;
    my ($in_fh, $out_fh) = @{$options}{qw/in_fh out_fh/};
    while(<$in_fh>){
        next if /^\s*#/ or /^\s*$/;
        die unless /^(\S+) (\S+)/;
        my ($geneid, $scl) = ($1, resolve_abbr($2));
        print $out_fh "$geneid\t$scl\n";
    }
}

sub main{
    my $options = get_options;
    process_wolfpsort($options);    
}

main() unless caller;
