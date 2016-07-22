#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script <MCScanX_GFF> <genelist>

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my ($gff,$genelist) = @ARGV;
    my %id;
    open my $genelist_fh, $genelist or die "$!";
    while(<$genelist_fh>){
        chomp;
        die "CAUTION: multiple ID $_ in $genelist" if $id{$_};
        $id{$_}++;
    }
    close $genelist_fh;

    my %gff;
    open my $gff_fh, $gff or die "$!";
    while(<$gff_fh>){
        chomp;
        my($chr, $id, $start, $end) = split /\t/;
        die "CAUTION: ID $id present multiple times in $gff!" if $gff{$id};
        ($start, $end) = ($end, $start) if $start > $end;
        $gff{$id} = [$chr, $start, $end];
    }
    close $gff_fh;

    for my $id (keys %id){
        die "No data of $id in $gff" unless $gff{$id};
    }

    my @all_ids = sort {$gff{$a}->[0] cmp $gff{$b}->[0] or
                        $gff{$a}->[1] <=> $gff{$b}->[1]} keys %gff;

    my %tandem;
    for my $i (1..$#all_ids){
        my ($a, $b) = @all_ids[$i-1, $i];
        if($id{$a} and $id{$b} and $gff{$a}->[0] eq $gff{$b}->[0]){
            #print "$a,$b\n";
            $tandem{$a} = $i - 1;
            $tandem{$b} = $i;
        }
    }

    for my $id (sort {$tandem{$a} <=> $tandem{$b}} keys %tandem){
       print join("\t", $id, $tandem{$id}, @{$gff{$id}}),"\n";
    }

    my @tandem_ids= sort {$tandem{$a} <=> $tandem{$b}} keys %tandem;
    print $tandem_ids[0];
    for my $i (1..$#tandem_ids){
        my $previous_id = $tandem_ids[$i -1];
        my $id = $tandem_ids[$i];
        if($tandem{$id} - $tandem{$previous_id} == 1 and
           $gff{$id}->[0] eq $gff{$previous_id}->[0]){
            print ",$id";
        }else{
            print "\n$id";
        }
    }
}

main unless caller;
