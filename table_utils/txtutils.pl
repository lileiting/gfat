#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main_usage{
    print <<"usage";

USAGE
    $FindBin::Script ACTION [OPTIONS]

DESCRIPTION
    A set of Perl version codes try to reproduce the 
    function of some basic shell tools, like fgrep, 
    uniq, etc. Here each tool possess some features 
    that its corresponding shell version might not have. 

AVAILABLE ACTIONS
    fgrep   | Exactly match a column, rather than match by 
              regular expression
    uniq    | Print uniq lines without preprocessing by 
              sort

usage
   exit;
}

sub main{
    main_usage unless @ARGV;
    my $action = shift @ARGV;
    if(defined &{\&{$action}}){
        &{\&{$action}}
    }
    else{
        die "CAUTION: Action $action was not defined!\n";
    }
    exit;
}

main() unless caller;

sub fgrep {
    print "fgrep\n";
}

sub uniq{
    my $args = new_action(
        -desc => 'Function like unix command \"uniq\", but 
                  do not need preprocessing by sort. This 
                  program will load the whole file into 
                  memory, so its not proper to used it on 
                  huge size files.',
        -options => { 
            "count|c" => 'Print the count of the number of
                          lines after each line and 
                          separated tab',
            "duplicate|d" => 'Only output lines that are 
                              repeated in the input',
            "uniq|u" => 'Only output lines that are not 
                         repeated in the input',
            "no_sort|t" => 'Do not sort the results 
                            (default output sorted results)'
                    }
    );

    my @uniq_lines;
    my %lines;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            unless($lines{$_}){
                push @uniq_lines, $_;
            }
            $lines{$_}++;
        }
    }

    @uniq_lines = sort{$a cmp $b}@uniq_lines 
        unless $args->{options}->{no_sort};

    for my $line (@uniq_lines){
        next if $args->{options}->{uniq} 
            and $lines{$line} > 1;
        next if $args->{options}->{duplicate} 
            and $lines{$line} == 1;
        print "$line", 
              $args->{options}->{count} ? 
                  "\t".$lines{$line} : '',
              "\n";
    }
}

__END__
