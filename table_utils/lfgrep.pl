#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long qw(:config gnu_getopt);
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionBase qw(load_listfile);

sub usage{
    print <<USAGE;

perl $FindBin::Script [OPTIONS]

  Get a subset of lines from a file based on a list
  of patterns(strings) by exact match the first 
  column. This is a replacement of Linux/Unix 
  command "fgrep -f FILE", which is too slow for a 
  larger dataset, in my experience. This script 
  build a hash for the list of patterns. Thus, the 
  patterns will be considered simply a set of 
  strings, instead of regular expression patterns. 

  [-f,--file] FILE  Input file, -f or --file could 
                    be omitted, piping in is allowed
  -l,--list   FILE  A list of strings, one per line.
                    Comments are allowed with prefix 
                    of "#"
  -o,--out    FILE  Output file, default:STDOUT
  -H,--header       Header present at the first line
  -h,--help         Print help

USAGE
    exit;
}

sub get_options{
    my ($in_fh, $out_fh) = (\*STDIN, \*STDOUT);
    GetOptions("file|f=s" => \my $infile,
               "list|l=s" => \my $listfile,
               "out|o=s"  => \my $outfile,
               "header|H" => \my $header,
               "help|h"   => \my $help);
    usage if $help or (@ARGV == 0 and -t STDIN);
    die "CAUTION: List file is missing!\n" unless $listfile;
    $infile = shift @ARGV if (!$infile and @ARGV > 0);
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;

    return {
        in_fh   => $in_fh,
        listfile => $listfile,
        out_fh   => $out_fh,
        header   => $header
    }
}

sub grep_file{
    my ($in_fh, $pattern, $out_fh, $header) = @_;
    if($header){
        my $title = <$in_fh>;
        print $out_fh $title;
    }
    while(<$in_fh>){
        chomp;
        my @F = split /\s+/;
        print $out_fh "$_\n" if $pattern->{$F[0]};
    }
}

sub main{
    my $options  = get_options;
    my $in_fh    = $options->{in_fh};
    my $listfile = $options->{listfile};
    my $out_fh   = $options->{out_fh};
    my $header   = $options->{header};
    my $pattern  = load_listfile($listfile);
    grep_file($in_fh, $pattern, $out_fh, $header);
}

main() unless caller;
