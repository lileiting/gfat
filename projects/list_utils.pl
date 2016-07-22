#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use File::Basename;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    my $dir = basename $FindBin::RealBin;
    print <<"end_of_usage";

USAGE
    gfat.pl $dir $FindBin::Script ACTION [OPTIONS]

ACTIONS
    list2matrix | Convert a list with three columns to a matrix

end_of_usage
    exit
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

#########################
# Defination of actions #
#########################

# Title: sort_by_type
# Description: Sort array by number if it is numerical, or by string
# Input: An array
# Output: An array

sub is_number{
    map{return 0 unless /^-?\d+(\.\d+)?$/}@_;
    return 1;
}

sub smart_sort{
    return is_number(@_) ?
       sort{$a <=> $b}@_ : sort{$a cmp $b}@_;
}

# Title: remove_redundant
# Description: Given an array, return the non-redundant, sorted elements
# Input: An array
# Output: An array

sub list2matrix{
    my $args = new_action(
        -desc => 'Convert a list with three columns to a matrix',
        -options => {
            "symm|s" => 'symmetrical for first two columns [default: asymmetrial]',
            "seperator|s=s" => 'Filed separator (default: tab)',
        }
    );

    my $symm = $args->{options}->{symm};
    my $field_separator = $args->{options}->{seperator} // "\t";
    my %data;
    my %first_column;
    my %second_column;
    my %first_two_columns;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            @_ = split /$field_separator/;
            die "CAUTION: Three columns are required!\n" unless @_ == 3;
            $data{$_[0]}->{$_[1]} = $_[2];
            $first_column{$_[0]}++;
            $second_column{$_[1]}++;
            $first_two_columns{$_[0]}++;
            $first_two_columns{$_[1]}++;
        }
    }

    my @row_names = smart_sort(keys %first_column);
    my @col_names = smart_sort(keys %second_column);

    if($symm){
        my @names = smart_sort(keys %first_two_columns);
        print "MATRIX$field_separator",
            join("$field_separator", @names), "\n";
        for my $row (@names){
            my $str = $row;
            for my $col (@names){
                $str .= $field_separator . ($data{$row}->{$col} //
                        $data{$col}->{$row} // '-');
            }
            print "$str\n";
        }
    }else{
        print "MATRIX$field_separator",
            join("$field_separator", @col_names), "\n";
        for my $row (@row_names){
            my $str = $row;
            for my $col (@col_names){
                $str .= $field_separator . ($data{$row}->{$col} // '-');
            }
            print "$str\n";
        }
    }
}
