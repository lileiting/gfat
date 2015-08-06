#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use Getopt::Long;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionBase qw(load_listfile);

sub usage{
    print <<EOF;

USAGE
  $FindBin::Script [OPTINOS] list1.txt list2.txt

DESCRIPTION
  Compare two list and find the union set, or intersection

OPTIONS
  -union         Print union set
  -intersection  Print intersection
  -1,--first     Print unique elements in first file
  -2,--first     Print unique elements in second file

EOF
    exit;
}

sub print_hash{
    my %hash = @_;
    for (sort {$a cmp $b} keys %hash){
        print "$_\n";
    }
}

sub print_union{
    my($list1, $list2) = @_;
    my %union;
    map{$union{$_}++}(keys %$list1, keys %$list2);
    print_hash(%union);
}

sub print_intersection{
    my ($list1, $list2) = @_;
    my %intersection;
    map{$intersection{$_}++ if $list2->{$_}}(keys %$list1);
    print_hash(%intersection);
}

sub print_first{
    my ($list1, $list2) = @_;
    my %first;
    map{$first{$_}++ if not $list2->{$_}}(keys %$list1);
    print_hash(%first);
}

sub print_second{
    my($list1,$list2) = @_;
    my %second;
    map{$second{$_}++ if not $list1->{$_}}(keys %$list2);
    print_hash(%second);
}

sub main{
    my %options;
    GetOptions(
        "union"        => \$options{union},
        "intersection" => \$options{intersection},
        "1|first"      => \$options{first},
        "2|second"     => \$options{second},
        "help"         => \$options{help}     
    );
    usage if $options{help} or @ARGV != 2 or 
        (not $options{union} and not $options{intersection} and 
         not $options{first} and not $options{second});
    my ($file1, $file2) = @ARGV;
    my $list1 = load_listfile($file1);
    my $list2 = load_listfile($file2);

    print_union($list1, $list2)        if $options{union};
    print_intersection($list1, $list2) if $options{intersection};
    print_first($list1, $list2)        if $options{first};
    print_second($list1, $list2)       if $options{second};

}

main() unless caller;
