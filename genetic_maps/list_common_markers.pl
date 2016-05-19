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
    list_common_markers(
        $consensus_map_file, $individual_map_file);
}

main unless caller;

sub list_common_markers{
    my ($consensus_map_file, $individual_map_file) = @_;
    
    my %out_fh;
    
    open my $consensus_map_fh, $consensus_map_file or die $!;
    my %consensus;
    while(<$consensus_map_fh>){
        chomp;
        my ($map_id, $LG, $marker, $pos) = split /\t/;
        $consensus{$marker} = [$LG,$pos];
    }
    close $consensus_map_fh;

    my %individual;
    open my $individual_map_fh, $individual_map_file or die $!;
    while(<$individual_map_fh>){
        chomp;
        my ($map_id, $LG, $marker, $pos) = split /\t/;
        $individual{$marker}->{$map_id}++;
    }
    close $individual_map_fh;

    my @marker_list = sort {$consensus{$a}->[0] <=> $consensus{$b}->[0] 
                        or $consensus{$a}->[1] <=> $consensus{$b}->[1]}
                       keys %consensus;
    for my $marker1 (@marker_list){
        my @map_ids = sort {$a cmp $b}keys %{$individual{$marker1}};
        next unless @map_ids > 1;
        print join("\t", @{$consensus{$marker1}}, $marker1, scalar(@map_ids),
               join(",", @map_ids))."\n";
        for my $map_id (@map_ids){
        }
    }
}

__END__