#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;


sub usage{
    print <<USAGE;

  $FindBin::Script - Merge multiple tables into one single table

  Merge multiple tables into one single table based
  on the first column. Assume title first line is 
  title.

  $FindBin::Script FILE [FILE ...]

USAGE
    exit;
}

sub read_table{
    my ($data, $title, @files) = @_;
    #warn "Read table from @files ...\n";
    for my $file_index (0..$#files){
        my $file = $files[$file_index];
        open my $fh, "<", $file or die "$file: $!";
        while(<$fh>){
            s/[\r\n]//g;
            my ($key, @F) = split /\t/;
            if ($. == 1){ # Title
                 die if $title->[0] and $title->[0] ne $key;
                 push @$title, $key unless $title->[0];
                 push @$title, map{"$file|$_"}@F;
            }else{
                 $data->{$key}->[$file_index] = [@F];
            }
        }
        close $fh;
    }
    my $num_of_keys = keys %$data;
    #warn "Number of keys: $num_of_keys\n";
    return ($data, $title, @files);
}

sub print_table{
    my ($data, $title, @files) = @_;
    my $num_of_cols = (scalar(@$title) - 1) / scalar(@files);
    #warn "Title elements: ", scalar(@$title), " Number of columns: $num_of_cols\n";
    print join("\t", @$title), "\n";
    my @keys = sort{$a cmp $b}(keys %$data);
    for my $key (@keys){
        my @row;
        for my $file_index (0..$#files){
            push @row, map {$data->{$key}->[$file_index]->[$_] // '-'}(0..$num_of_cols - 1);
        }
        print "$key\t", join("\t", @row),"\n";
    }
}

sub main{
    usage unless @ARGV;
    my @files = @ARGV;
    my $data = {};
    my $title = [];
    # Data structure: HASH => {KEY} => [FILE] => [ROW]
    print_table(read_table($data, $title, @files));
}

main() unless caller;
