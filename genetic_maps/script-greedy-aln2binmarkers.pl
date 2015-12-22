#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw/min max/;

sub main_usage{
    print <<"usage";

    $FindBin::Script <input>

usage
    exit;
}

sub are_bin_markers{
    my ($array_ref, $i, $j) = @_;
    my @positions;
    my %scaffolds;
    for ($i .. $j){
        my ($id, $scf, $start, $end) = @{$array_ref->[$_]};
        push @positions, $start, $end;
        $scaffolds{$scf}++;
    }
    my $min_pos = min(@positions);
    my $max_pos = max(@positions);
    return 0 if keys %scaffolds > 1;
    return 0 if ($max_pos - $min_pos + 1) > 10000;
    return 1;
}

sub print_bin{
    my ($array_ref, $i, $j, $bin_count) = @_;
    my @positions;
    my %scaffolds;
    my %ids;
    for ($i .. $j){
        my ($id, $scf, $start, $end) = @{$array_ref->[$_]};
        push @positions, $start, $end;
        $scaffolds{$scf}++;
        $ids{$id}++;
    }
    my @ids = sort {$a cmp $b} keys %ids;
    my $min_pos = min(@positions);
    my $max_pos = max(@positions);
    my ($scaffold) = keys %scaffolds;
    printf "Bin%04d\t%s\t%d\t%d\t%d\t%s\n", 
        $bin_count,
        $scaffold, 
        $min_pos, 
        $max_pos, 
        scalar(@ids),
        join(",", @ids);
    return 1;
}

sub main{
    main_usage unless @ARGV;
    my $infile = shift @ARGV;
    open my $fh, $infile or die $!;
    my @data;
    while(<$fh>){
        chomp;
        push @data, [split /\t/];
    }
    close $fh;

    my $bin_count = 0;
    my %binmarkers;
    for(my $i = 0; $i <= $#data; $i++){
        my $j = $i + 1;
        while($j <= $#data){
            last unless are_bin_markers(\@data, $i, $j);
            $j++;
        }
        $bin_count++;
        print_bin(\@data, $i, $j - 1, $bin_count);
        $i = $j - 1; 
    }
}

main unless caller;

__END__
