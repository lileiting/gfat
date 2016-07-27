#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub usage{
    print <<"end_of_usage";

Usage
    $FindBin::Script <map data>

end_of_usage
    exit;
}

sub main{
    usage unless @ARGV;
    my $infile = shift @ARGV;
    open my $fh, $infile or die $!;
    my @data;
    while(<$fh>){
        chomp;
        @_ = split /\t/;
        push @data, [@_];
    }
    close $fh;
    my @LG_order = (8, 15, 2, 7, 1, 6, 14, 12, 4, 16, 13, 17, 9, 11, 3, 10, 5);
    my $i = 0;
    my %LG_order = map{$i++;$_ => $i}@LG_order;
    @data = sort {$LG_order{$a->[1]} <=> $LG_order{$b->[1]}
                 or $a->[3] <=> $b->[3]
               } @data;
    
    my %marker;
    for (@data){
        my ($map_id, $LG, $marker, $pos) = @$_;
        if($marker =~ /^(.+)-\d$/){
            $marker{$1}++;
        }
        print join("\t", "feature", $map_id, $LG, $marker, 
                         "marker", $pos)."\n";
    }
    for (@data){
        my ($map_id, $LG, $marker, $pos) = @$_;
        print join("\t", "feature", "$map_id-", $LG, $marker, 
                         "marker", $pos)."\n";
    }

    my %base;
    for (@data){
        @_ = @$_;
        for my $key (keys %marker){
            if($_[2] =~ /$key/){
                #print "$key\t$_";
                push @{$base{$key}}, $_;
                last;
            }
        }
    }

    for my $key (sort {$a cmp $b} keys %base){
        my @array = @{$base{$key}};
        my %count_LG;
        for (@array){
            @_ = @$_;
            $count_LG{$_[1]}++;
        }
        next if keys %count_LG < 2;
        #for (@array){
        #    print "$key\t$_\n";
        #}
        for (my $i = 0; $i < $#array; $i++){
            for (my $j = $i+1; $j<= $#array; $j++){
                my ($map_id1, $LG1, $marker1, $pos1) = @{$array[$i]};
                my ($map_id2, $LG2, $marker2, $pos2) = @{$array[$j]};
                next if $marker1 eq $marker2;
                print join("\t", "homolog", $map_id1, $marker1, 
                                  "$map_id2-", $marker2, 0)."\n";
            }
        }
    }
}

main unless caller;

__END__