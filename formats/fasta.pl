#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Getopt::Long;
use Bio::Perl;
use Gfat::Cmd::Base qw(base_main close_fh);
use Gfat::Cmd::BioBase qw(get_seqio close_seqio);
use List::Util qw/sum/;

sub actions{
    return {
        idlist    => [\&idlist_fasta , "Get ID list of a sequence file"                  ],
        length    => [\&length_fasta , "Print sequence length"                           ],
        sort      => [\&sort_fasta   , "Sort sequences by name/sizes"                    ],
        rmdesc    => [\&rmdesc_fasta , "Remove sequence descriptions"                    ],
        getseq    => [\&action_getseq, "Get sequences by ID pattern"                     ],
        translate => [\&translate_cds, "Translate CDS to protein sequence"               ],
        gc        => [\&gc_content   , "GC content"                                      ],
        clean     => [\&clean_fasta  , "Clean irregular chars"                           ],
        revcom    => [\&revcom_fasta , "Reverse complementary sequences"                 ],
        format    => [\&format_fasta , "Format FASTA sequences 60 bp per line"           ],
        oneline   => [\&oneline_fasta, "Format FASTA sequences unlimited length per line"],
        n50       => [\&N50          , "Calculate N50"                                   ],
        motif     => [\&motif_search , "Print sequences match a pattern, e.g. WRKY"      ],
        ssr       => [\&find_ssr     , "Find SSR sequences"                              ]
    }
}

base_main(actions) unless caller;

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

=head2 action_getseq

  Title      : action_getseq

  Usage      : fasta.pl getseq [OPTIONS]

  Description: Get sequences from a FASTA file with a seqname, a pattern
               or a list of seqnames

  Options    : [-i,--input] <FASTA>
               -o,--output FILE
               -h,--help
               -s,--seqname STR
               -p,--pattern STR 
               -l,--listfile <FILE>

  Examples  : fasta.pl getseq in.fasta -s gene1
              fasta.pl getseq in.fasta -s gene1 -s gene2
              fasta.pl getseq in.fasta -s gene1,gene2
              fasta.pl getseq in.fasta -p 'gene\d'
              fasta.pl getseq in.fasta -l list.txt
              fasta.pl getseq in.fasta -s gene1 -s gene2 -s gene3,gene4 -p 'name\d' -l list.txt 

=cut

sub load_list_file{
    my $file = shift;
    my %listid;
    open my $fh, "<", $file or die "$file: $!";
    while(<$fh>){
        next if /^\s*#/ or /^\s*$/;
        chomp;
        $listid{$_}++;
    }
    close $fh;
    return %listid;
}

sub action_getseq{
    my ($in, $out, $options) = get_seqio(q/getseq/, 
        "p|pattern=s" =>  "STR    Pattern for sequence IDs",
        "s|seqname=s@" =>  "STR    Match the exactly sequence name (could be multiple)",
        "l|listfile=s" => "STR    A file contains a list of sequence IDs");
    my $pattern = $options->{pattern};
    my @seqnames = $options->{seqname} ? split(/,/,join(',',@{$options->{seqname}})) : ();
    my $listfile = $options->{listfile};
    die "ERROR: Pattern was not defined!\n" 
        unless $pattern or @seqnames or $listfile;
    my %listid = load_list_file($listfile) if $listfile;
    map{$listid{$_}++}@seqnames if @seqnames;
    while(my $seq = $in->next_seq){
        my $seqid = $seq->display_id;
        $out->write_seq($seq) if  
            ($pattern and $seqid =~ /$pattern/) or
            ((@seqnames or $listfile) and $listid{$seqid});
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
    print $out_fh join("\t", qw/ID          Seq_Name           Start              
                                End         SSR                Length 
                                Repeat_Unit Repeat_Unit_Length Repeatitions 
                                Sequence/
                      )."\n";
    while(my $seq = $in->next_seq){
        my ($sequence, $seq_name) = ($seq->seq, $seq->display_id);
        while($sequence =~ /(([ATGC]{2,6}?)\2{3,})/g){
            my ($match, $repeat_unit) = ($1, $2);
            my ($repeat_length, $SSR_length)=(length($repeat_unit), length($match));
            if($match =~ /([ATGC])\1{5}/){next;}
            $id++;
            print $out_fh join("\t", 
                $id,            $seq_name,      pos($sequence)-$SSR_length+1,
                pos($sequence), $match,         $SSR_length,
                $repeat_unit,   $repeat_length, $SSR_length / $repeat_length,
                substr($sequence, 
                    pos($sequence) - $SSR_length - $flank_seq_length,
                    $SSR_length + $flank_seq_length * 2)
            )."\n";
        }
    }
}

__END__
