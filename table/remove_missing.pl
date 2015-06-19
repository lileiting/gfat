#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;

sub usage{
    print <<USAGE;

perl $FindBin::Script [OPTIONS]

 [-i,--input]  FILE
 -o,--output   FILE
 -h,--help

USAGE
    exit;
}

sub get_options{
    GetOptions(
        "input=s"  => \my $infile,
        "output=s" => \my $outfile,
        "help"     => \my $help
    );
    usage if $help or (!$infile and @ARGV == 0 and -t STDIN);
    my ($in_fh, $out_fh) = (\*STDIN, \*STDOUT);
    $infile = shift @ARGV if (!$infile and @ARGV > 0);
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;

    return {
        in_fh => $in_fh,
        out_fh => $out_fh
    };
}

sub present_missing{
    my $line = shift;
    chomp $line;
    my @F = split /\s+/;
    for my $i (@F){
        return 1 if $i eq q/-/;
    }
    return 0;
}

sub main{
    my $options = get_options;
    my $in_fh = $options->{in_fh};
    my $out_fh = $options->{out_fh};

    while(<$in_fh>){
        next if present_missing($_);
        print $out_fh $_;
    }
}

main() unless caller;
