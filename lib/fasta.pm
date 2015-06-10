package fasta;
use warnings;
use strict;
use Getopt::Long;
use Bio::Perl;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(idlist_fasta sort_fasta rmdesc_fasta);
@EXPORT_OK = @EXPORT;

sub print_fasta_usage{
    my $cmd = shift;
    print <<USAGE;

$FindBin::Script $cmd <FASTA>

USAGE
    exit;
}

sub idlist_fasta{
    print_fasta_usage(q/idlist/) unless @ARGV;
    my $infile = shift @ARGV;
    my $outfh = \*STDOUT;
    my $in = Bio::SeqIO->new(-file=>$infile, -format=>q/fasta/);
    while(my $seq = $in->next_seq){
        print $outfh $seq->display_id, "\n";
    }
}

sub sort_fasta{
    print_fasta_usage(q/sort/) unless @ARGV;
    my $infile = shift @ARGV;
    my $outfh = \*STDOUT;
    my @seqobjs = read_all_sequences($infile, q/fasta/);
    my $out = Bio::SeqIO->new(-fh => $outfh, -format=>q/fasta/);
    map{$out->write_seq($_)}(sort{$a->display_id cmp $b->display_id}@seqobjs);
    exit;
}

sub format_seqstr{
    my $str = shift;
    my $len = length($str);
    $str =~ s/(.{60})/$1\n/g;
    chomp $str;
    return $str;
}

sub rmdesc_fasta{
    print_fasta_usage(q/rmdesc/) unless @ARGV;
    my $infile = shift @ARGV;
    my $outfh = \*STDOUT;
    my $in = Bio::SeqIO->new(-file=>$infile, -format=>q/fasta/);
    while(my $seq = $in->next_seq){
        my $seqid = $seq->display_id;
        my $seqstr = format_seqstr($seq->seq);
        print $outfh qq/>$seqid\n$seqstr\n/;
    }
}

1;
