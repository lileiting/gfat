#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use Bio::Perl;

sub main_usage{
    print <<"usage";

    $FindBin::Script <input.gb>

usage
    exit;
}

sub main{
    main_usage unless @ARGV == 1;
    my $input = shift @ARGV;
    my $in = Bio::SeqIO->new(-file => $input, -format => 'genbank');
    while(my $seq = $in->next_seq){
        my $seq_id = $seq->display_id;
        my $desc = $seq->desc;
        print qq/$desc\n/ and next
            unless $desc =~ /satellite.+?((Tsu|EMPc|NH|NB|BGT)\w+)/i;
        my $ssr_id = $1;
        my @primer_seqs;
        my @features = $seq->get_SeqFeatures();
        foreach my $feat ( @features ) {
            next unless $feat->primary_tag eq 'primer_bind';
            push @primer_seqs, $feat->seq->seq;
        }

        print join("\t", $seq_id, $ssr_id, @primer_seqs)."\n";

    }
}

main unless caller;
