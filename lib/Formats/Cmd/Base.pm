package Formats::Cmd::Base;
use warnings;
use strict;
use FindBin;
use Getopt::Long;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(get_fh close_fh);
@EXPORT_OK = @EXPORT;

sub cmd_usage{
    my $cmd = shift;
    print <<USAGE;

perl $FindBin::Script $cmd [OPTIONS]

 [-i,--input]  FILE
 -o,--output   FILE
 -h,--help

USAGE
    exit;
}

sub get_options{
    my $cmd = shift;
    GetOptions(
        "input=s"  => \my $infile,
        "output=s" => \my $outfile,
        "help"     => \my $help
    );
    cmd_usage($cmd) if $help or (!$infile and @ARGV == 0 and -t STDIN);
    my ($in_fh, $out_fh) = (\*STDIN, \*STDOUT);
    $infile = shift @ARGV if (!$infile and @ARGV > 0);
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;

    return {
        in_fh => $in_fh,
        out_fh => $out_fh
    };
}

sub get_fh{
    my $cmd = shift;
    my $options = get_options($cmd);
    my $in_fh = $options->{in_fh};
    my $out_fh = $options->{out_fh};
    return ($in_fh, $out_fh);
}

sub close_fh{
    my @fhs = @_;
    for my $fh (@fhs){
        close $fh unless 
               $fh eq \*STDIN  or 
               $fh eq \*STDOUT or 
               $fh eq \*STDERR;
    }
}

1;
