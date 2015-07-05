#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Getopt::Long;
use Bio::Perl;
use Gfat::Cmd::Base qw(get_options base_main close_fh);
use Gfat::Cmd::BioBase qw(get_seqio close_seqio);
use List::Util qw/sum/;

sub base_usage{
    print <<USAGE;

Usage:
    perl $FindBin::Script ACTION

Available ACTIONs:
     idlist | Get ID list of a sequence file
     length | Print sequence length
       sort | Sort sequences by name/sizes
     rmdesc | Remove sequence descriptions
     getseq | Get sequences by ID pattern
  translate | Translate CDS to protein sequence
         gc | GC content
      clean | Clean irregular chars
     revcom | Reverse complementary sequences
     format | Format FASTA sequences 60 bp per line
    oneline | Format FASTA sequences unlimited length per line
        n50 | Calculate N50

USAGE
    exit;
}

sub functions_hash{
    return {
        idlist    => \&idlist_fasta ,
        length    => \&length_fasta ,
        sort      => \&sort_fasta   ,
        rmdesc    => \&rmdesc_fasta ,
        getseq    => \&getseq_fasta ,
        translate => \&translate_cds,
        gc        => \&gc_content   ,
        clean     => \&clean_fasta  ,
        revcom    => \&revcom_fasta ,
        format    => \&format_fasta ,
        oneline   => \&oneline_fasta,
        n50       => \&N50
    }
}

base_main(&functions_hash, \&base_usage);

#############################
# Defination of subcommands #
#############################

sub idlist_fasta{
    my ($in, undef, $options) =  get_seqio(q/idlist/, 
        "d|desc" => "Print description in header");
    my ($out_fh, $desc) = @{$options}{qw/out_fh desc/};
    while(my $seq = $in->next_seq){
        print $out_fh $seq->display_id,
                      $desc ? ' '.$seq->desc : '',
                      "\n";
    }
}

sub length_fasta{
    my ($in, undef, $options) = get_seqio(q/length/);
    my ($out_fh) = @{$options}{out_fh};
    while(my $seq = $in->next_seq){
        print $out_fh $seq->display_id,"\t",$seq->length,"\n";
    }
}

sub sort_fasta{
    my ($in, $out, $options) = get_seqio(q/sort/, 
        "s|sizes" => "Sort by sizes (default by ID name)");
    my $sizes = $options->{sizes};
    my @seqobjs;
    while(my $seq = $in->next_seq){push @seqobjs, $seq}
    map{$out->write_seq($_)}( sort{ $sizes ? 
            $b->length <=> $a->length : 
            $a->display_id cmp $b->display_id
        }@seqobjs);
}

sub rmdesc_fasta{
    my ($in, $out) = get_seqio(q/rmdesc/);
    while(my $seq = $in->next_seq){
        $out->write_seq(
            Bio::PrimarySeq->new(-display_id => $seq->display_id,
                                 -seq => $seq->seq));
    }
}

sub getseq_fasta{
    my ($in, $out, $options) = get_seqio(q/getseq/, 
        "p|pattern" => "Pattern for sequence IDs");
    my $pattern = $options->{pattern};
    while(my $seq = $in->next_seq){
        my $seqid = $seq->display_id;
        $out->write_seq($seq) if $seqid =~ /$pattern/;
    }
}

sub translate_cds{
    my ($in, $out) = get_seqio(q/translate/);
    while(my $seq = $in->next_seq){
        $out->write_seq(translate($seq));
    }
}

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
        $out->write_seq(
            Bio::PrimarySeq->new(-display_id => $seq->display_id,
                                 -description => $seq->desc,
                                 -seq => join('', grep{/[A-Za-z*]/}split(//, $seq->seq))));
    }
    close_seqio($in, $out);
}

sub revcom_fasta{
    my ($in, $out) = get_seqio(q/clean/);
    while(my $seq = $in->next_seq){
        $out->write_seq($seq->revcom);
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

sub calculate_N50{
    my @num = sort{$b <=> $a}@_;
    my $total = sum(@num);
    my $sum = 0;
    for my $n (@num){
        $sum += $n;
        return $n if $sum >= $total / 2;
    }
}

sub N50{
    my ($in, undef, $options) = get_seqio(q/n50/);
    my $out_fh = $options->{out_fh};
    my @seqlen;
    while(my $seq = $in->next_seq){
        push @seqlen, $seq->length;
    }
    my $n50 = calculate_N50(@seqlen);
    print $out_fh "N50: $n50\n";
}

__END__
