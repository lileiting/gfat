#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Getopt::Long;
use Bio::Perl;
use GFAT::ActionBase qw(base_main close_fh load_listfile);
use GFAT::ActionBioBase qw(get_seqio close_seqio);
use List::Util qw/sum max min/;

sub actions{
    return {
        -description => 'FASTA sequence',
        format => [
            \&format_fasta,
            "Format FASTA sequences 60 bp per line"
        ],
        oneline => [
            \&oneline_fasta,
            "Format FASTA sequences unlimited length per line"
        ],
        motif => [
            \&motif_search,
            "Print sequences match a pattern, e.g. WRKY"
        ],
        ssr => [
            \&find_ssr,
            "Find SSR sequences"
        ]
    }
}

base_main(actions) unless caller;

#############################
# Defination of subcommands #
#############################

sub motif_search{
    my ($in, $out, $options) = get_seqio(q/motif/,
        "p|pattern=s" => "Sequence pattern");
    my $pattern = $options->{pattern};
    while(my $seq = $in->next_seq){
        my $seqstr = $seq->seq;
        $out->write_seq($seq) if $seqstr =~ /$pattern/;
    }
    close_seqio($in, $out);
}

sub find_ssr{
    my ($in, undef, $options) = get_seqio(q/ssr/);
    my $out_fh = $options->{out_fh};
    # Defination of SSR:
    # Repeat unit 2bp to 6bp, length not less than 18bp
    my ($id, $flank_seq_length) = (0, 100);
    print $out_fh join("\t",
        qw/ID          Seq_Name           Start
           End         SSR                Length
           Repeat_Unit Repeat_Unit_Length Repeatitions
           Sequence/
        )."\n";
    while(my $seq = $in->next_seq){
        my ($sequence, $seq_name) = ($seq->seq, $seq->display_id);
        while($sequence =~ /(([ATGC]{2,6}?)\2{3,})/g){
            my ($match, $repeat_unit) = ($1, $2);
            my ($repeat_length, $SSR_length)=
                (length($repeat_unit), length($match));
            if($match =~ /([ATGC])\1{5}/){next;}
            $id++;
            print $out_fh join("\t",
                $id,
                $seq_name,
                pos($sequence)-$SSR_length+1,
                pos($sequence),
                $match,
                $SSR_length,
                $repeat_unit,
                $repeat_length,
                $SSR_length / $repeat_length,
                substr($sequence,
                    pos($sequence) - $SSR_length - $flank_seq_length,
                    $SSR_length + $flank_seq_length * 2)
            )."\n";
        }
    }
}

__END__
