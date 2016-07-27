#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub usage{
    print <<"end_of_usage";

USAGE
    $FindBin::Script <data.map>

end_of_usage
    exit;
}

sub main{
    usage unless @ARGV;
    my $size = 5;
    
    my $infile = shift @ARGV;
    my %map;
    open my $fh, $infile or die $!;
    while(<$fh>){
        chomp;
        my ($LG, $marker, $pos) = split /\t/;
        $map{$LG}->{$marker} = $pos;
    }
    close $fh;

    my $cluster = 0;
    for my $LG (sort {$a <=> $b} keys %map){
        my @markers = sort {$map{$LG}->{$a} <=> $map{$LG}->{$b}}
            keys %{$map{$LG}};
        my $LG_length = $map{$LG}->{$markers[-1]};
        for (my $i = 0; $i < @markers; $i++){
            my $pos_i = $map{$LG}->{$markers[$i]};
            my $n = 0;
            my $j;
            for ($j = $i; $j < @markers; $j++){
                my $pos_j = $map{$LG}->{$markers[$j]};
                last if $pos_j > $pos_i + $size;
                $n++;
            }
            if($n >= 10){
                $cluster++;
                for ($i..$j-1){
                    my $pos = $map{$LG}->{$markers[$_]};
                    my $cluster_mid_pos = $map{$LG}->{$markers[$i]} + $size/2;
                    print join("\t", 
                        $LG, $markers[$_], $pos, 
                        $cluster, 
                        $cluster_mid_pos,
                        $LG_length,
                        sprintf("%.1f", $cluster_mid_pos / $LG_length * 100),
                        $j - $i
                    )."\n";
                }
                $i = $j - 1;
            }
            else{
                print join("\t", 
                    $LG, $markers[$i], $pos_i, 'not_in_cluster')."\n";
            }
        }
    }
}

main unless caller;

__END__
