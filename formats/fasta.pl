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
        gc => [
            \&gc_content,
             "GC content"   
        ],
        clean => [
            \&clean_fasta,
            "Clean irregular chars"
        ],
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

sub count_gc{
    my $str = shift;
    my @char = split //, $str;
    my %char;
    map{$char{$_}++}@char;
    my $gc = ($char{G} // 0) + ($char{C} // 0);
    my $at = ($char{A} // 0) + ($char{T} // 0);
    return ($gc, $at);
}

sub gc_content{
    my ($in, undef, $options) = get_seqio(q/gc/);
    my $out = $options->{out_fh};
    my $total_len = 0;
    my $gc = 0;
    my $at = 0;
    while(my $seq = $in->next_seq){
        $total_len += $seq->length;
        my ($seq_gc, $seq_at) = count_gc($seq->seq);
        $gc += $seq_gc;
        $at += $seq_at;
    }
    printf $out "GC content: %.2f %%\n", $gc / ($gc+$at) * 100;
    my $non_atgc = $total_len - ($gc + $at);
    printf $out "Non-ATGC characters: %d of %d (%.2f %%)\n",
               $non_atgc, $total_len, $non_atgc / $total_len * 100
           if $non_atgc;
}

sub clean_fasta{
    my ($in, $out) = get_seqio(q/clean/);
    while(my $seq = $in->next_seq){
        my $cleaned_seq = join('',
            grep{/[A-Za-z*]/}split(//, $seq->seq));
        $out->write_seq(
            Bio::PrimarySeq->new(-display_id => $seq->display_id,
                                 -description => $seq->desc,
                                 -seq => $cleaned_seq));
    }
    close_seqio($in, $out);
}

sub format_fasta{
    my ($in, $out) = get_seqio(q/format/);
    while(my $seq = $in->next_seq){
        $out->write_seq($seq);
    }
    close_seqio($in, $out);
}

sub oneline_fasta{
    my ($in, undef, $options) = get_seqio(q/oneline/);
    my $out_fh = $options->{out_fh};
    while(my $seq = $in->next_seq){
        my $id = $seq->display_id;
        my $desc = " ".$seq->desc;
        my $seq = $seq->seq;
        print $out_fh ">$id$desc\n$seq\n";
    }
    close_seqio($in);
    close_fh($out_fh);
}

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
