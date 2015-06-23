#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;

sub usage{
    print <<USAGE;

NAME
    $FindBin::Script - A script to get window statistics from a gene positions file

DESCRIPTION
    Assume the table contains four columns:
    ID    Chr    Start    End
    Particularly, the ID contains the type 
    information, e.g. Pbr1_a2, underscore is required,
    "a" is type, 2 will be ignored 

SYNOPSIS
    $FindBin::Script [OPTIONS]
    $FindBin::Script input.txt
    $FindBin::Script -i input.txt
    $FindBin::Script input.txt -o output.txt
    $FindBin::Script input.txt -w 500000

OPTIONS
    [-i,--input]   FILE

    -o,--output    FILE
        Default print results to STDOUT

    -w,--window    NUM
        Default: 1_000_000

COPYRIGHT
    Copyright (c) 2015 by Leiting Li
    This program is part of GFATK, see https://github.com/lileiting/gfatk
    for more information.

USAGE
    exit;
}

sub get_options{
    GetOptions(
        "input=s"  => \my $infile,
        "output=s" => \my $outfile,
        "window=i" => \my $window_size,
        "help"     => \my $help
    );
    usage if $help or (@ARGV == 0 and not $infile and -t STDIN);
    my $in_fh = \*STDIN;
    $infile = shift @ARGV if !$infile and @ARGV > 0;
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    my $out_fh = \*STDOUT;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;
    $window_size ||= 1_000_000;
    die "CAUTION: window size $window_size!\n" unless $window_size > 0;

    return {
        in_fh => $in_fh,
        out_fh => $out_fh,
        window_size => $window_size
    }
}

sub get_type{
    my $str = shift;
    my (undef, $type) = split /_/, $str;
    $type =~ s/\d//g;
    return $type;
} 

sub load_file{
    my ($in_fh, $window) = @_;
    my %data;
    #warn "Loading data ...\n";
    my $count;
    while(<$in_fh>){
        $count++;
        next unless /^(\S+)\s+(\S+)\s+(\d+)\s+(\d+)/;
        my ($id, $chr, $start, $end) = ($1,$2,$3,$4);
        my $type = get_type($id);
        %{$data{$id}} = (
            id   => $id,
            type => $type,
            chr  => $chr,
            start=> $start,
            end  => $end
        );
    }
    #warn "Done! $count lines!\n";
    return \%data;
}

sub analyze_data{
    my ($data, $window_size) = @_;
    my %stats;
    for my $id (keys %$data){
        my $chr   = $data->{$id}->{chr};
        my $start = $data->{$id}->{start};
        my $end   = $data->{$id}->{end};
        my $type  = $data->{$id}->{type};
        my $window = int(($start + $end) / 2 / $window_size) + 1;
        $stats{stats}->{$chr}->{$window}->{$type}++;
        $stats{type}->{$type}++;
    }
    $stats{window_size} = $window_size;
    return \%stats;
}

sub by_number{
    my $chr = shift;
    die "CAUTION: Chromosome name $chr\n" 
        unless $chr =~ /^\S*?(\d+)$/; 
    $chr =~ s/^\S*?(\d+)$/$1/;
    return $chr;
}

sub get_unit{
    my $window_size = shift;
    if($window_size == 1_000_000){return "Mb"}
    else{return "${window_size}bp"}
}

sub print_results{
    my($results, $out_fh) = @_;
    my @types = sort{$a cmp $b}(keys %{$results->{type}});
    my $window_size = $results->{window_size};
    my $unit = get_unit($window_size);
    my $title = join("\t", qq/Chr Pos($unit)/, @types)."\n";  
    print $out_fh $title;
    for my $chr (sort {by_number($a) <=> by_number($b)} keys %{$results->{stats}}){
        for my $pos (sort{$a <=> $b}(keys %{$results->{stats}->{$chr}})){
            print $out_fh join("\t", $chr, $pos, 
                          map{$results->{stats}->{$chr}->{$pos}->{$_} // 0}
                          @types), "\n";
        }
    } 
}

sub main{
    my $options = get_options;
    my $in_fh = $options->{in_fh};
    my $out_fh = $options->{out_fh};
    my $window_size = $options->{window_size};

    my $data = load_file($in_fh);
    my $results = analyze_data($data, $window_size);
    print_results($results, $out_fh);

}

main() unless caller;

