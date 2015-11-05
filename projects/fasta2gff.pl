#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::SeqActionNew;

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]

DESCRIPTION

AVAILABLE ACTIONS
    fasta2gff | Convert FASTA sequences to a pseudoGFF file


usage
    exit
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    main_usage unless $action =~ /^[a-z]/;
    if(defined &{\&{$action}}){
        &{\&{$action}}
    }else{
        die "CAUTION: Action $action was not defined!";
    }
}

main unless caller;

sub fasta2gff{
    my $args = new_seqaction(
        -desc => 'Convert Fasta sequence to a pseudoGFF file'
    );
    for my $io (@{$args->{in_ios}}){
        while(my $seq = $io->next_seq){
            my $id = $seq->display_id;
            my $len = $seq->length;
            
        }
    }

}

__END__
