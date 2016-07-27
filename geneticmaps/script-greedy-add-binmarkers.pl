#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw(sum);

sub main_usage{
    print <<"usage";

    $FindBin::Script <all marker list> <bin markers info>

usage
    exit;
}

sub main{
    main_usage unless @ARGV == 2;
    my ($all_markers_file, $bin_markers_file) = @ARGV;
    my %map_data;
    my %marker_data;
    open my $all_markers_fh, $all_markers_file or die $!;
    while(<$all_markers_fh>){
        chomp;
        my ($map_id, $LG, $marker, $LG_pos, $type) = split /\t/;
        die "CAUTION: duplicated marker name: $marker !!!\n"
            if exists $map_data{$map_id}->{$LG}->{$marker};
        $map_data{$map_id}->{$LG}->{$marker} = $LG_pos;
        push @{$marker_data{$marker}}, [$map_id, $LG, $LG_pos];
    }
    close $all_markers_fh;

    open my $bin_markers_fh, $bin_markers_file or die $!;
    while(<$bin_markers_fh>){
        chomp;
        my ($binmarker, $scaffold, $start, $end, $count, $marker_list)
            = split /\t/;
        next if $count == 1;
        my @markers = split /,/, $marker_list;
        
        # If all markers were in the same map, same LG, then omit this
        # bin marker
        my %check_LG;
        for my $marker(@markers){
            for my $marker_info(@{$marker_data{$marker}}){
                my ($map_id, $LG, $LG_pos) = @$marker_info;
                $check_LG{$map_id."#LG#".$LG}++;
            }
        }
        next if keys %check_LG == 1;

        # If this bin marker should keep and there were multiple
        # markers in one LG, then choose average LG position as 
        # the position of this bin marker.

        my %bin_marker_info;
        for my $marker (@markers){
           for my $marker_info (@{$marker_data{$marker}}){
               my ($map_id, $LG, $LG_pos) = @$marker_info;
               $bin_marker_info{$map_id}->{$LG}->{$marker} = $LG_pos;
           }
        }
        for my $map_id (keys %bin_marker_info){
            for my $LG (keys %{$bin_marker_info{$map_id}}){
               my %hash = %{$bin_marker_info{$map_id}->{$LG}};
               my $bin_marker_pos = sum(values %hash) / scalar(keys %hash);
               print join("\t", $binmarker, $map_id, $LG, $bin_marker_pos, 
                                join(",", sort {$a cmp $b} keys %hash),
                                join(",", map {$hash{$_}} sort {$a cmp $b} keys %hash)
                         )."\n";
            }
        }




        # Print bin marker information
        #for my $marker (@markers){
        #    for my $marker_info (@{$marker_data{$marker}}){
        #        my ($map_id, $LG, $LG_pos) = @$marker_info;
        #        print join("\t", $binmarker, $map_id, $LG, $LG_pos, $marker)."\n";
        #    }
        #}

    }
    close $bin_markers_fh;
}

main unless caller;

__END__
