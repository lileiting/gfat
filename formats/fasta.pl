#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Getopt::Long;
use Bio::Perl;
use Formats::Cmd::Base qw(base_main);
use Formats::Cmd::BioBase qw(get_seqio);

sub base_usage{
    print <<USAGE;

$FindBin::Script CMD [OPTIONS]

CMD:
     idlist | Get ID list of a sequence file
     length | Print sequence length
       sort | Sort sequences by name/sizes
     rmdesc | Remove sequence descriptions
     getseq | Get sequences by ID pattern
  translate | Translate CDS to protein sequence
         gc | GC content
      clean | Clean irregular chars
     revcom | Reverse complementary sequences

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
    }
}

base_main(&functions_hash, \&base_usage);

#############################
# Defination of subcommands #
#############################

sub print_fasta_usage{
    my $cmd = shift;
    my %opt_desc = (
        sort   => qq/\n  -s,--sizes          Sort sequences by sizes/, 
        idlist => qq/\n  -d,--desc           With description/,
        getseq => qq/\n  -p,--pattern STR    Pattern for sequence IDs/
    );

    my $opt_desc = $opt_desc{$cmd} // '';

    print <<USAGE;

$FindBin::Script $cmd [OPTIONS]

  [-i,--input] <FILE>
  -o,--output  <FILE> Default to STDOUT$opt_desc
  -h,--help

USAGE
    exit;
}

sub get_options{
    my $cmd = shift;
    my ($infile, $outfile, $in_fh, $out_fh);
    my $pattern;
    my ($sizes, $desc, $help);
    GetOptions(
        "i|input=s"  => \$infile,
        "o|output=s" => \$outfile,
        "s|sizes"    => \$sizes,
        "d|desc"     => \$desc,
        "p|pattern=s"=> \$pattern,
        "h|help"     => \$help
    );
    print_fasta_usage($cmd) if $help or (!$infile and @ARGV == 0 and -t STDIN);
    print_fasta_usage($cmd) if $cmd eq q/getseq/ and !$pattern;

    $in_fh = \*STDIN;
    $infile = shift @ARGV if !$infile and @ARGV > 0;
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    $out_fh = \*STDOUT;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;

    my $in_io = Bio::SeqIO->new(-fh => $in_fh, -format => q/fasta/);
    my $out_io= Bio::SeqIO->new(-fh => $out_fh,-format => q/fasta/);

    return {
        in_io => $in_io,
        out_fh => $out_fh,
        out_io => $out_io, 
        sizes => $sizes, 
        desc => $desc,
        pattern => $pattern
    };
}

sub idlist_fasta{
    my $options = get_options(q/idlist/);
    my $in = $options->{in_io};
    my $out_fh = $options->{out_fh};
    my $desc = $options->{desc};
    while(my $seq = $in->next_seq){
        print $out_fh $seq->display_id,
                      $desc ? ' '.$seq->desc : '',
                      "\n";
    }
    exit;
}

sub length_fasta{
    my $options = get_options(q/length/);
    my $in = $options->{in_io};
    my $out_fh = $options->{out_fh};
    while(my $seq = $in->next_seq){
        print $out_fh $seq->display_id,"\t",$seq->length,"\n";
    }
    exit;
}

sub sort_fasta{
    my $options = get_options(q/sort/);
    my $in = $options->{in_io};
    my $out = $options->{out_io};
    my $sizes = $options->{sizes};
    my @seqobjs;
    while(my $seq = $in->next_seq){push @seqobjs, $seq}
    if($sizes){
        map{$out->write_seq($_)}(
            sort{$b->length <=> $a->length}
            @seqobjs);
    }else{
        map{$out->write_seq($_)}(
            sort{$a->display_id cmp $b->display_id}
            @seqobjs);
    }
    exit;
}

sub rmdesc_fasta{
    my $options = get_options(q/rmdesc/);
    my $in = $options->{in_io};
    my $out = $options->{out_io};
    while(my $seq = $in->next_seq){
        $out->write_seq(
            Bio::PrimarySeq->new(-display_id => $seq->display_id,
                                 -seq => $seq->seq));
    }
    exit;
}

sub getseq_fasta{
    my $options = get_options(q/getseq/);
    my $in = $options->{in_io};
    my $out = $options->{out_io};
    my $pattern = $options->{pattern};
    while(my $seq = $in->next_seq){
        my $seqid = $seq->display_id;
        $out->write_seq($seq) if $seqid =~ /$pattern/;
    }
}

sub translate_cds{
    my $options = get_options(q/translate/);
    my $in = $options->{in_io};
    my $out = $options->{out_io};
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
    my $options = get_options(q/gc/);
    my $in = $options->{in_io};
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
}

sub revcom_fasta{
    my ($in, $out) = get_seqio(q/clean/);
    while(my $seq = $in->next_seq){
        $out->write_seq($seq->revcom);
    }
}

__END__
