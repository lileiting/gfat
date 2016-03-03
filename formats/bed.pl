#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use File::Basename;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    my $category = basename $FindBin::RealBin;
    print <<"end_of_usage";

USAGE
    gfat.pl $category $FindBin::Script ACTION [OPTIONS]

DESCRIPTION
    Manipulating bed files

OPTIONS
    isPcr   | Processing results from isPcr
    cmp     | Compare isPcr results with its input SSR list

end_of_usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}};
    }
    else{
        die "CAUTION: action $action was not defined!\n";
    }
}

main() unless caller;

############################################################
# Defination of Actions                                    #
############################################################

sub cmp{
    my $args = new_action(
        -desc => 'Compare SSR name in bed file with the input SSR name list',
        -options => {
            "ssr_table|s=s" => 'Input SSR sequence table, three columns,
                                first column is SSR name, second column is
                                forward primer, and third column is reverse
                                column'

        }
    );
    my %input_ssr;
    my %data;
    my $ssr_table = $args->{options}->{ssr_table};
    open my $ssr_table_fh, $ssr_table or die "$!";
    while(<$ssr_table_fh>){
        chomp;
        @_ = split /\t/;
        die "The SSR table file should be 3 columns: $_" unless @_ == 3;
        $input_ssr{$_[0]} = [@_[1,2]];
    }
    close $ssr_table_fh;
    my @in_fhs = get_in_fhs $args;
    for my $fh (@in_fhs){
        while (<$fh>) {
            chomp;
            my ($scf, $start, $end, $name, $score, $strand) = split /\t/;
            push @{$data{$name}}, [$scf, $start, $end, $name, $score, $strand];
        }
    }
    for my $name (sort {$a cmp $b} keys %input_ssr ){
        print join("\t", $name,
                         exists $data{$name} ? "YES" : "NO",
                         exists $data{$name} ? scalar(@{$data{$name}}) : "NA",
                         @{$input_ssr{$name}}
            )."\n";
    }
}

sub isPcr{
    # bed - tab delimited format. Fields: chrom/start/end/name/score/strand
    my $args = new_action(
        -desc => 'Processing results from isPcr',
    );
    my %data;
    my @in_fhs = get_in_fhs $args;
    for my $fh (@in_fhs){
        while(<$fh>){
            chomp;
            my ($scf, $start, $end, $name, $score, $strand) = split /\t/;
            push @{$data{$name}}, [$scf, $start, $end, $name, $score, $strand];
        }
    }
    for my $name (sort {$a cmp $b} keys %data){
        my @array = @{$data{$name}};
        if(@array == 1){
            print join("\t", @{$array[0]}),"\n";
        }
        else{
            @array = sort {$b->[4] <=> $a->[4]} @array;
            my @scores = map {$_->[4]} @array;
            my ($first, $second) = @scores;
            next if $first == $second;
            print join("\t", @{$array[0]}),"\n";
            next;
            my $rate = join("/", @scores);
            for my $info (@array){
                print join("\t", "$rate:", @$info),"\n";
            }
        }
    }
}
