#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long qw(:config gnu_getopt);
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use Math::GSL::Statistics qw/gsl_stats_correlation/;
use Math::GSL::CDF qw/gsl_cdf_tdist_P/;

sub main_usage{
    print <<"usage";

Usage
    $FindBin::Script ACTION [OPTIONS]

Description
    Input is a data matrix, which defined as,
    1) frist row is sample names
    2) first column is observation names
    3) one row per observation
    4) one column per sample

Available Actions
    pcor   | calculate pairwise correlation
    filter | Filter the results from pcor 

    cor2sif| A shortcut for running both pcor and filter
    
    sifinfo| Print information for sif format files (number 
             of nodes and edges)

usage
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

main unless caller;

###################
# Define Actions #
###################

sub load_matrix{
    my $fh = shift;
    my @matrix;
    while(<$fh>){
        chomp;
     	push @matrix, [split /\t/];
    }
    return \@matrix;
}

sub remove_missing_data{
    my ($data1, $data2) = @_;
    my $n1 = scalar(@$data1);
    my $n2 = scalar(@$data2);
    die "number of elements in two vectors are not same: $n1, $n2" 
        unless $n1 == $n2;
    my @valid_index;
    for (my $i = 0; $i < $n1; $i++){
        my $num1 = $data1->[$i];
        my $num2 = $data2->[$i];
        push @valid_index, $i if $num1 > -2 and $num2 > -2;
    }
    my $n = scalar(@valid_index);
    $data1 = [@{$data1}[@valid_index]];
    $data2 = [@{$data2}[@valid_index]];
    return ($data1, $data2, $n);
}

sub cal_cor{
    my ($matrix, $i, $j) = @_;
    my ($id1, @vector1) = @{$matrix->[$i]};
    my ($id2, @vector2) = @{$matrix->[$j]};
    my $data1 = [@vector1];
    my $data2 = [@vector2];
    my $n;
    ($data1, $data2, $n) = remove_missing_data($data1, $data2);
    return($id1, $id2, 'nan', 1, $n, 'nan') if $n < 3;
    my $cor = gsl_stats_correlation($data1, 1, $data2, 1, $n);
    return($id1, $id2, 1,     0, $n, 'nan') if $cor >= 1;
    my $pvalue = 1;
    my $t;
    $t =  $cor / sqrt((1 - $cor ** 2) / ($n - 2));
    $pvalue = (1 - gsl_cdf_tdist_P(abs($t), $n - 2)) * 2;
    return ($id1, $id2, $cor, $pvalue, $n, $t);
}

sub pcor{
    my $args = new_action(
        -desc => 'Calculate pairwise correlation using Statistic::Basic'
    );

    my $fh = $args->{in_fhs}->[0];
    my $matrix = load_matrix($fh);

    for(my $i = 1; $i <= $#{$matrix} - 1; $i++){
        for (my $j = $i + 1; $j <= $#{$matrix}; $j++){
            my ($id1, $id2, $cor, $pvalue, $n, $t) = cal_cor($matrix, $i, $j);
            print join("\t", $id1, $id2, $cor, $pvalue, $n, $t)."\n";
        }
    }
}

sub filter{
    my $args = new_action(
        -desc => 'Filter results from pcor',
        -options => {
            "rate|r=f@" => 'Pearson correlation coefficient 
                           threshold [default: 0.7, 0.8, 0.9, 
                           0.95, 0.99]'
        }
    );
    my $sig_level = 0.01;
    my @rates;
    if($args->{options}->{rate}){ 
        @rates = split(/,/, join(",", @{$args->{options}->{rate}}));
    }
    else{
        @rates = (0.99, 0.95, 0.90, 0.80, 0.70);
    }

    my $in_fh = $args->{in_fhs}->[0];
    my $infile = $args->{infiles}->[0];
    my %fhs;
    for my $rate (@rates){
        warn "Rate: $rate\n";
        open $fhs{$rate}->{cor}, ">", "$infile.$rate.cor" or die $!;
        open $fhs{$rate}->{sif}, ">", "$infile.$rate.sif" or die $!;
    }

    while(<$in_fh>){
        next unless /^(\S+)\t(\S+)\t(\S+)\t(\S+)/;
        my ($id1, $id2, $cor, $pvalue) = ($1, $2, $3, $4);
        for my $rate (@rates){
            if ($cor >= $rate and $pvalue < $sig_level){
                print {$fhs{$rate}->{cor}} $_;
                print {$fhs{$rate}->{sif}} "$id1\tco\t$id2\n";
            }
        }
    }
    
    for my $rate(keys %fhs){
        close $fhs{$rate}->{cor};
        close $fhs{$rate}->{sif};
    }
}

sub cor2sif{
    my $args = new_action(
        -desc => 'A shortcut for running both pcor and filter'
    );

    my $infile = $args->{infiles}->[0];
    system("perl $0 pcor $infile -o $infile.cor");
    system("perl $0 filter $infile.cor");
}

sub sifinfo{
    my $args = new_action(
        -desc => 'Print information in a sif format file: number of nodes
                  and edges'
    );
    my @in_fhs = @{$args->{in_fhs}};
    my @infiles = @{$args->{infiles}};
    for(my $i = 0; $i < scalar(@in_fhs); $i++){
        my $in_fh = $in_fhs[$i];
        my $infile = $infiles[$i];
        my %nodes;
        my $edges = 0;
        while(<$in_fh>){
            next if /^\s*$/ or /^\s*#/;
            $edges++;
            chomp;
            @_ = split /\t/;
            $nodes{$_[0]}++;
            $nodes{$_[2]}++;
        }
        my $nodes = keys %nodes;
        print join("\t", $infile, $nodes, $edges)."\n";
    }
}

__END__