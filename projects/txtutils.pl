#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw(min max sum);
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
our $in_desc = '<tab file> [<tab file> ...]';

sub main{
    my %actions = (
        cc     => 'Character count',
        fgrep  => 'Exactly match a column, rather than match by
            regular expression',
        linesep => 'Fix line seperator, convert \r\n or \r to \n',
        linelen => 'Print length of each line and statistics',
        uniq   => 'Print uniq lines without preprocessing by
            sort',
        -desc  => 'A set of Perl version codes try to reproduce the
            function of some basic shell tools, like fgrep,
            uniq, etc. Here each tool possess some features
            that its corresponding shell version might not have.'
    );
    &{\&{run_action(%actions)}};
}

sub cc{
    my $args = new_action(
        -desc => 'Character count'
    );

    my %char;
    for my $fh (@{$args->{in_fhs}}){
        my $char = '';
        while(read($fh, $char, 1)){
            $char{ord($char)}++;
        }
    }

    for my $ord (sort {$a <=> $b} keys %char){
        my $count = $char{$ord};
        my $char = $ord >= 33 && $ord <= 126 ? chr($ord) : "chr($ord)";
        print "$ord\t$char\t$count\n";
    }
}

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
            "listfile|l=s" => 'A list of strings, one per line.
                    Comments are allowed with prefix of "#"',
            "invert_match|v" => 'Selected lines are those not
                      matching any of the specified patterns.',
            "column_list|C=i" => "Column in the list file that treat as patterns [default: 1]",
            "column|c=i" => 'Column in files used for test the patterns [default: 1]',
            "header|H" => 'Header present at the first line',
            "pattern|p=s@" => 'Additional patterns besides which in
                    the list file [could be multiple]'
        }
    );
    my $listfile = $args->{options}->{listfile};
    my @patterns = $args->{options}->{pattern} ?
        @{$args->{options}->{pattern}} : ();
    my $column_list = $args->{options}->{column_list} // 1;
    my $column = $args->{options}->{column} // 1;

    die "CAUTION: A file with a list of patterns is required!\n"
        unless $listfile or $args->{options}->{pattern};
    my %pattern;
    if($listfile){
        open my $fh, $listfile or die "$!: $listfile\n";
        while(<$fh>){
            chomp;
            next if /^\s*$/ or /^\s*#/;
            my @F = split /\s+/;
            my $pattern = $F[$column_list - 1];
            die "Error in list file!\n" if $pattern eq '';
            $pattern{$pattern}++;
        }
        close $fh;
    }
    map{ $pattern{$_}++ }@patterns;

    for my $in_fh (@{$args->{in_fhs}}){
        if($args->{options}->{header}){
            my $title = <$in_fh>;
            print $title;
        }
        while(<$in_fh>){
            chomp;
            my @F = split /\s+/;
            next unless defined $F[$column - 1];
            my $matched = exists $pattern{$F[0]} ? 1 : 0;
            $matched = not $matched if $args->{options}->{invert_match};
            print "$_\n" if $matched;
        }
    }
}

sub linelen {
    my $args = new_action(
        -desc => 'Print length of each line and statistics'
    );

    my @stats;
    my $line_count = 0;
    for my $fh (@{$args->{in_fhs}}){
        while(my $line = <$fh>){
            $line_count++;
            chomp($line);
            my $len = length($line);
            print "$line_count\t$.\t$len\n";
            push @stats, $len;
        }
    }

    my $num = scalar(@stats);
    my $min = min(@stats);
    my $max = max(@stats);
    my $sum = sum(@stats);
    my $avg = $num > 0 ? $sum / $num : 0;
    warn "#--- Statistics ---#\n";
    warn "Num\t$num\n";
    warn "Min\t$min\n";
    warn "Max\t$max\n";
    warn "Sum\t$sum\n";
    warn "Avg\t$avg\n";
    warn "#-----------------#\n";
}

sub linesep {
    my $args = new_action(
        -desc => 'Fix line seperator, \r\n or \r to \n'
    );

    for (my $i = 0; $i <= $#{ $args->{infiles} }; $i++){
        my $infile = $args->{infiles}->[$i];
        my $fh = $args->{in_fhs}->[$i];
        open my $out_fh, ">$infile.bak2" or die $!;
        while(<$fh>){
            s/\r(\n)?/\n/g;
            print $out_fh $_;
        }
        close $out_fh;
        close $fh;
        rename $infile, "$infile.bak";
        rename "$infile.bak2", "$infile";
        warn "$infile ... fixed\n";
        warn "Backup file: $infile.bak\n";
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

main() unless caller;

__END__
