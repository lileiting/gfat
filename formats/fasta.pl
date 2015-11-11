#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use GFAT::SeqAction;

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]

ACTIONS
    acclist  | Print a list of accession numbers
    clean    | Clean irregular characters
    filter   | Filter sequences by size and Number of Ns or Xs
    format   | Read in and write out sequences
    fromtab  | Convert 2-column sequence to FASTA format
    gc       | GC content
    getseq   | Get sequences by IDs
    getseq2  | Output sequences by the order of input IDs
    identical| Find identical records from multiple files
    ids      | Print a list of sequence IDs
    motif    | Find sequences with given sequence pattern
    oneline  | Print one sequence in one line
    rename   | Rename sequence IDs
    revcom   | Reverse complementary
    rmdesc   | Remove sequence descriptions
    seqlen   | Print a list of sequence length
    seqsort  | Sort sequences by name/size
    ssr      | Find simple sequence repeats (SSR)
    subseq   | Get subsequence
    subseq2  | Get subsequences based on input file (ID, start, end,
               strand, new ID)
    translate| Translate CDS to protein sequences

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    our $format = 'fasta';
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}}; 
    }
    elsif(GFAT::SeqAction->can($action)){
        GFAT::SeqAction->$action();
    }
    else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main() unless caller;

sub fromtab{
    my $args = new_action(
        -desc => 'Convert 2-column sequence to FASTA format 
                  [Copied function from tanghaibao\'s
                   python -m jcvi.formats.fasta fromtab]',
        -options => {
            "sep|s=s" => 'Separator in the tabfile [default: tab]',
            "replace|r=s" => 'Replace spaces in name to char 
                              [default: none]',
            "length|l=i" => 'Output sequence length per line 
                             [default: unlimited]',
            "fasta|f"    => 'A shortcut for --length=60'
                    }
    );

    my $options = $args->{options};

    my $sep     = $options->{sep} // "\t";
    my $replace = $options->{replace};
    my $length  = $options->{length};
    my $fasta   = $options->{fasta};

    $length = 60 if $fasta and not $length;

    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            next if /^\s*$/ or /^\s*#/;
            chomp;
            my ($id, $seq) = split /$sep/;
            $id =~ s/ /$replace/g if $replace;
            if($length){
                $seq =~ s/(.{$length})/$1\n/g;
                chomp $seq;
            }
            print ">$id\n$seq\n";
        }
    }
}

__END__
