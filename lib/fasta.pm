package fasta;
use warnings;
use strict;
use Getopt::Long;
use Bio::Perl;
use FormatSeqStr;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(fasta_cmd);
@EXPORT_OK = @EXPORT;

sub print_fasta_usage{
    my $cmd = shift;
    my $sizes = $cmd eq q/sort/ ? 
        qq/\n  -s,--sizes          Sort sequences by sizes/ 
        : '';
    my $desc = $cmd eq q/idlist/ ?
        qq/\n  -d,--desc           With description/
        : '';
    print <<USAGE;

$FindBin::Script $cmd [OPTIONS]

  [-i,--input] <FILE>
  -o,--output  <FILE>$sizes$desc
  -h,--help

USAGE
    exit;
}

sub read_commands{
    my $cmd = shift;
    my ($infile, $outfile, $in_fh, $out_fh);
    my ($sizes, $desc, $help);
    GetOptions(
        "i|input=s"  => \$infile,
        "o|output=s" => \$outfile,
        "s|sizes"    => \$sizes,
        "d|desc"     => \$desc,
        "h|help"     => \$help
    );
    print_fasta_usage($cmd) if $help or (!$infile and @ARGV == 0 and -t STDIN);
    $in_fh = \*STDIN;
    $infile = shift @ARGV if !$infile and @ARGV > 0;
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    $out_fh = \*STDOUT;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;
    return ($in_fh, $out_fh, $sizes, $desc);
}

sub idlist_fasta{
    my($in_fh, $out_fh, undef, $desc) = read_commands(q/idlist/);
    my $in = Bio::SeqIO->new(-fh => $in_fh, -format=>q/fasta/);
    while(my $seq = $in->next_seq){
        print $out_fh $seq->display_id,
                      $desc ? ' '.$seq->desc : '',
                      "\n";
    }
    exit;
}

sub length_fasta{
    my($in_fh, $out_fh) = read_commands(q/length/);
    my $in = Bio::SeqIO->new(-fh => $in_fh, -format=>q/fasta/);
    while(my $seq = $in->next_seq){
        print $out_fh $seq->display_id,"\t",$seq->length,"\n";
    }
    exit;
}

sub sort_fasta{
    my ($in_fh, $out_fh, $sizes) = read_commands(q/sort/);
    my @seqobjs;
    my $in = Bio::SeqIO->new(-fh => $in_fh, -format=>q/fasta/);
    while(my $seq = $in->next_seq){push @seqobjs, $seq}
    my $out = Bio::SeqIO->new(-fh => $out_fh, -format=>q/fasta/);
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
    my ($in_fh, $out_fh) = read_commands(q/rmdesc/);
    my $in = Bio::SeqIO->new(-fh => $in_fh, -format=>q/fasta/);
    while(my $seq = $in->next_seq){
        my $seqid = $seq->display_id;
        my $seqstr = format_seqstr($seq->seq);
        print $out_fh qq/>$seqid\n$seqstr\n/;
    }
    exit;
}

#----------------------------------------------------------#

sub fasta_cmd{
    my $cmd = shift;
    if(   $cmd eq q/idlist/){ idlist_fasta }
    elsif($cmd eq q/length/){ length_fasta }
    elsif($cmd eq q/sort/  ){ sort_fasta   }
    elsif($cmd eq q/rmdesc/){ rmdesc_fasta }
}

1;
