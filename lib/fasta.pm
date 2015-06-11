package fasta;
use warnings;
use strict;
use Getopt::Long;
use Bio::Perl;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(fasta_cmd);
@EXPORT_OK = @EXPORT;

sub fasta_cmd{
    my $cmd = shift;
    if($cmd eq q/idlist/){
        &idlist_fasta;
    }elsif($cmd eq q/length/){
        &length_fasta;
    }elsif($cmd eq q/sort/){
        &sort_fasta;
    }elsif($cmd eq q/rmdesc/){
        &rmdesc_fasta;
    }
}

sub print_fasta_usage{
    my $cmd = shift;
    my $sizes = $cmd eq q/sort/ ? 
        qq/\n  -s,--sizes          Sort sequences by sizes/ 
        : '';
    print <<USAGE;

$FindBin::Script $cmd [OPTIONS]

  [-i,--input] <FILE>
  -o,--output  <FILE>$sizes
  -h,--help

USAGE
    exit;
}

sub read_commands{
    my $cmd = shift;
    my $help;
    my $infile;
    my $outfile;
    my $sizes;
    my ($in_fh, $out_fh);
    GetOptions(
        "i|input=s"  => \$infile,
        "o|output=s" => \$outfile,
        "s|sizes"     => \$sizes,
        "h|help"      => \$help
    );
    print_fasta_usage($cmd) if $help or (!$infile and @ARGV == 0 and -t STDIN);
    $in_fh = \*STDIN;
    $infile = shift @ARGV if !$infile and @ARGV > 0;
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    $out_fh = \*STDOUT;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;
    return ($in_fh, $out_fh, $sizes);
}

#----------------------------------------------------------#

sub format_seqstr{
    my $str = shift;
    my $len = length($str);
    $str =~ s/(.{60})/$1\n/g;
    chomp $str;
    return $str;
}

#----------------------------------------------------------#

sub idlist_fasta{
    my($in_fh, $out_fh) = read_commands(q/idlist/);
    my $in = Bio::SeqIO->new(-fh => $in_fh, -format=>q/fasta/);
    while(my $seq = $in->next_seq){
        print $out_fh $seq->display_id,"\n";
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

1;
