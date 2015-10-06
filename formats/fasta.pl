#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::SeqAction;

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]

ACTIONS
    acclist  | Print a list of accession numbers
    clean    | Clean irregular characters
    format   | Read in and write out sequences
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

__END__
