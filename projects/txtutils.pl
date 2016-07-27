#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use GFAT::LoadFile;

sub fgrep {
    my $args = new_action(
        -desc => 'Get a subset of lines from a file based on a list
                 of patterns(strings) by exact match the first
                 column. This is a replacement of Linux/Unix
                 command "fgrep -f FILE", which is too slow for a
                 larger dataset, in my experience. This script
                 build a hash for the list of patterns. Thus, the
                 patterns will be considered simply a set of
                 strings, instead of regular expression patterns. ',
        -options => {
            "file|f=s" => 'A list of strings, one per line.
                    Comments are allowed with prefix of "#"',
            "invert_match|v" => 'Selected lines are those not
                      matching any of the specified patterns.',
            "header|H" => 'Header present at the first line'
        }
    );
    die "CAUTION: A file with a list of patterns is required!\n"
        unless $args->{options}->{file};
    my $pattern  = load_listfile($args->{options}->{file});
    for my $in_fh (@{$args->{in_fhs}}){
        if($args->{options}->{header}){
            my $title = <$in_fh>;
            print $title;
        }
        while(<$in_fh>){
            chomp;
            my @F = split /\s+/;
            next unless defined $F[0];
            if($args->{options}->{invert_match}){
                print "$_\n" if not $pattern->{$F[0]};
            }else{
                print "$_\n" if $pattern->{$F[0]}
            }
        }
    }
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

sub main{
    my %actions = (
        fgrep  => 'Exactly match a column, rather than match by
            regular expression',
        uniq   => 'Print uniq lines without preprocessing by
            sort',
        -desc  => 'A set of Perl version codes try to reproduce the
            function of some basic shell tools, like fgrep,
            uniq, etc. Here each tool possess some features
            that its corresponding shell version might not have.'
    );
    &{\&{run_action(%actions)}};
}

main() unless caller;

__END__
