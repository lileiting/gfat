#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub main_usage{
    print <<"end_of_usage";

USAGE
    $FindBin::Script <consensus map> <individual map>

end_of_usage
    exit;
}

sub main{
    main_usage unless @ARGV == 2;
    my ($consensus_map_file, $individual_map_file) = @ARGV;
    convert_map_data_to_strudel_data(
        $consensus_map_file, $individual_map_file);
}

main unless caller;

sub convert_map_data_to_strudel_data{
    my ($consensus_map_file, $individual_map_file) = @_;
    
    my %out_fh;
    
    open my $consensus_map_fh, $consensus_map_file or die $!;
    my %consensus;
    while(<$consensus_map_fh>){
        chomp;
        my ($map_id, $LG, $marker, $pos) = split /\t/;
        unless(exists $out_fh{$LG}){
            open $out_fh{$LG}, "> $consensus_map_file.LG$LG.strudel" 
                or die $!;
        }
        $consensus{$marker} = $LG;
        print {$out_fh{$LG}} join("\t", 'feature', 'Consensus_map', 
                         "LG$LG", $marker, 'marker', 
                         sprintf("%.1f", $pos))."\n";
    }
    close $consensus_map_fh;

    my %individual;
    open my $individual_map_fh, $individual_map_file or die $!;
    while(<$individual_map_fh>){
        chomp;
        my ($map_id, $LG, $marker, $pos) = split /\t/;
        $individual{$marker}->{$map_id}++;
        print {$out_fh{$LG}} join("\t", 'feature', 'Individual_map', $map_id,
                                  "$marker|$map_id",'marker', $pos)."\n";
    }
    close $individual_map_fh;

    for my $marker1 (sort {$a cmp $b} keys %consensus){
        my @map_ids = sort {$a cmp $b}keys %{$individual{$marker1}};
        # pick color from http://colorbrewer2.org
        my $color = @map_ids > 1 ? "\t#8856A7" : "\t#A9A9A9";
        for my $map_id (@map_ids){
            print {$out_fh{$consensus{$marker1}}} join("\t", 'homolog',
                'Consensus_map', $marker1, 'Individual_map',
                "$marker1|$map_id", 0, $color)."\n";
        }
    }
}

