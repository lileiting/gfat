#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub main_usage{
    print <<"end_of_usage";

USAGE
    $FindBin::Script <map1> <map2>

end_of_usage
    exit;
}

sub main{
    main_usage unless @ARGV == 2;
    my ($map1_file, $map2_file) = @ARGV;
    convert_map_data_to_strudel_data(
        $map1_file, $map2_file);
}

main unless caller;

sub convert_map_data_to_strudel_data{
    my ($map1_file, $map2_file) = @_;
    
    my $map1_map_id;
    open my $map1_fh, $map1_file or die $!;
    my %map1;
    my @data1;
    while(<$map1_fh>){
        chomp;
        my ($map_id, $LG, $marker, $pos) = split /\t/;
        push @data1, [$map_id, $LG, $marker, $pos];
        unless($map1_map_id){
            $map1_map_id = $map_id
        }
        else{
            die "ERROR, expected one map ID, but ".
                "found two: $map1_map_id, $map_id" 
                if $map1_map_id ne $map_id
        }
        $map1{$marker} = $LG;

    }
    close $map1_fh;
    
    for (sort {$a->[1] <=> $b->[1] or $a->[3] <=> $b->[3]} @data1){
        my ($map_id, $LG, $marker, $pos) = @$_;
        print join("\t", 'feature', $map_id, 
                         "LG$LG", $marker, 'marker', 
                         sprintf("%.1f", $pos))."\n";
    }
    
    my %map2;
    open my $map2_fh, $map2_file or die $!;
    while(<$map2_fh>){
        chomp;
        my ($map_id, $LG, $marker, $pos) = split /\t/;
        $map2{$marker}->{$map_id}++;
        print join("\t", 'feature', $map_id, 
                         "LG$LG", $marker,'marker', 
                         sprintf("%.1f", $pos))."\n";
    }
    close $map2_fh;

    for my $marker1 (sort {$a cmp $b} keys %map1){
        for my $marker2 (sort {$a cmp $b} keys %map2){
            if(is_homolog($marker1, $marker2)){
                for my $map_id (sort {$a cmp $b}keys %{$map2{$marker2}}){
                    print join("\t", 'homolog',
                        $map1_map_id, $marker1, $map_id,
                        $marker2, 0)."\n";
                }
                last;
            }
        }
    }
}

sub is_homolog{
    my ($marker1, $marker2) = @_;
    return 1 if $marker1 eq $marker2;
    $marker1 =~ s/-\d$//;
    $marker2 =~ s/-\d$//;
    return 1 if $marker1 eq $marker2;
    return 0;
}
