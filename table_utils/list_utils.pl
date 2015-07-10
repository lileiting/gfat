#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use File::Basename;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Gfat::Cmd::Base qw(base_main get_fh close_fh);

sub actions{
    return {
        l2m => [\&list2matrix, "Convert a list with three columns to a matrix"]
    };
}

base_main(actions) unless caller;

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

sub sort_by_type{
    return is_number(@_) ? 
       sort{$a <=> $b}@_ : sort{$a cmp $b}@_;
}

# Title: remove_redundant
# Description: Given an array, return the non-redundant, sorted elements
# Input: An array
# Output: An array

sub remove_redundant{
    my %elements;
    map{$elements{$_}++}@_;
    return sort_by_type(keys %elements);
}

sub list2matrix{
    my ($in_fh, $out_fh, $options) = get_fh(q/l2m/, 
        "symm" => "symmetrical for first two columns [default: asymmetrial]",
        "t|field_separator=s" =>  "Filed separator (default: tab)");
    my $symm = $options->{symm};
    my $field_separator = $options->{field_separator} // "\t";
    my %data;
    while(<$in_fh>){
        chomp;
        @_ = split /$field_separator/;
        die "CAUTION: Three columns are required!\n" unless @_ == 3;
        $data{$_[0]}->{$_[1]} = $_[2];
    }

    my @row_names = sort_by_type(keys %data);
    my @col_names;
    map{push @col_names, (keys %{$data{$_}})}(keys %data);

    @col_names = remove_redundant(@col_names);

    if($symm){
        my @names = sort_by_type(@row_names, @col_names);
        print $out_fh "MATRIX$field_separator",
            join("$field_separator", @names), "\n";
        for my $row (@names){
            my $str = $row;
            for my $col (@names){
                $str .= $field_separator . ($data{$row}->{$col} // 
                        $data{$col}->{$row} // '-');
            }
            print $out_fh "$str\n";
        }
    }else{
        print $out_fh "MATRIX$field_separator",
            join("$field_separator", @col_names), "\n";
        for my $row (@row_names){
            my $str = $row;
            for my $col (@col_names){
                $str .= $field_separator . ($data{$row}->{$col} // '-');
            }
            print $out_fh "$str\n";
        }
    }

    close_fh($in_fh, $out_fh)
}
