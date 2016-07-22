#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub usage{
    print <<"usage";

USAGE
    $FindBin::Script <input.needle> [<input.needle> ...]

DESCRIPTION
    This is a simple program to extract some basic
    information from alignment files with emboss format,
    i.e. results from programs of needle or water with
    default format (pair, or srspair).

    Generally, 1) use bp_sreformat.pl to convert the
    format of alignment files; 2) use bioaln to do some
    basic operations.

usage
    exit;
}

sub print_title;
sub process_file;

sub main{
    usage unless @ARGV;
    print_title;
    map{process_file($_)}@ARGV;
    exit;
}

main unless caller;

sub print_title{
    print "Gene1\tGene2\tIdentity\n";
}

sub process_file{
    my $file = shift;
    open my $fh, "<", $file or die "$file:$!";
    while(<$fh>){
        next unless /^# ([12I].*):\s*(.+)$/;
        my ($key,$value)= ($1, $2);
        if(   $key eq '1'){print $value}
        elsif($key eq '2'){print "\t$value"}
        elsif($key eq 'Identity'){
            $value =~ s/^.*\((\d+\.\d)\%\).*$/$1/;
            print "\t$value\n"}
        else{die "CAUTION: the key is not 1, 2, or Idenity!"}
    }
    close $fh;
}
