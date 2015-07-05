#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use List::Util qw(sum max min);
use Gfat::Cmd::Base qw(base_main);

sub base_usage{
    print <<USAGE;

perl $FindBin::Script CMD [OPTIONS]

  Dealing with matrix.
  Matrix was defined as, 
  1) one row per observation
  2) one column per sample, 
  3) frist row is sample names, 
  4) first column is observation names

  csv2tab  | Replace any comma to tab
  tab2csv  | Replace any tab to comma

  rowsum   | Print sum for each row of a matrix (first row is title, 
             first column is observation name)
  rowmax   | Print maximum number for each row
  rowmin   | Print minimum number for each row
  colsum   | Print column sum of a matrix
  colmax   | Print maximum number for each column
  colmin   | Print minimum number for each column
  sum      | Print sum for the whole matrix
  max      | Print maximum for the whole matrix
  min      | Print minimum for the whole matrix
  size     | Print matrix size, number of rows, columns

  rmissing | Remove rows with missing data("-")
  rm1      | Remove rows with value less than 1
  groupbest| Get best observation for each group, group name is 
             inside observation name, i.e. for Gene1|A, "A" is 
             group name

  log      | Print log for each number, e as base

USAGE
    exit;
}

sub actions{
    return {
        rmissing  => [ \&rmissing   , q/Remove rows with missing data("-")/],
        csv2tab   => [ \&csv2tab    , "Replace any comma to tab" ], 
        tab2csv   => [ \&tab2csv    , "Replace any tab to comma" ],
        rowsum    => [ \&rowsum     , "Print sum for each row of a matrix (first row is title first column is observation name)"],
        rowmax    => [ \&rowmax     , "Print maximum number for each row"],
        rowmin    => [ \&rowmin     , "Print minimum number for each row"],
        colsum    => [ \&colsum     , "Print column sum of a matrix"],
        colmax    => [ \&colmax     , "Print maximum number for each column" ],
        colmin    => [ \&colmin     , "Print minimum number for each column"],
        sum       => [ \&matrix_sum , "Print sum for the whole matrix" ],
        max       => [ \&matrix_max , "Print maximum for the whole matrix" ],
        min       => [ \&matrix_min , "Print minimum for the whole matrix" ], 
        size      => [ \&matrix_size, "Print matrix size, number of rows, columns" ],
        rm1       => [ \&rm1        , "Remove rows with value less than 1"],
        groupbest => [ \&groupbest  , q/Get best observation for each group, group name is inside observation name, i.e. for Gene1|A, "A" is group name/ ],
        log       => [ \&math_log   , "Print log for each number, e as base"]
    }
}

base_main(actions) unless caller;

###################
# Define commands #
###################

#
# Common subroutines
#

sub cmd_usage{
    my $cmd = shift;
    print <<USAGE;

perl $FindBin::Script $cmd [OPTIONS]

 [-i,--input]  FILE
 -o,--output   FILE
 -h,--help

USAGE
    exit;
}

sub get_options{
    my $cmd = shift;
    GetOptions(
        "input=s"  => \my $infile,
        "output=s" => \my $outfile,
        "help"     => \my $help
    );
    cmd_usage($cmd) if $help or (!$infile and @ARGV == 0 and -t STDIN);
    my ($in_fh, $out_fh) = (\*STDIN, \*STDOUT);
    $infile = shift @ARGV if (!$infile and @ARGV > 0);
    open $in_fh, "<", $infile or die "$infile: $!" if $infile;
    open $out_fh, ">", $outfile or die "$outfile: $!" if $outfile;

    return {
        in_fh => $in_fh,
        out_fh => $out_fh
    };
}

sub get_fh{
    my $cmd = shift;
    my $options = get_options($cmd);
    my $in_fh = $options->{in_fh};
    my $out_fh = $options->{out_fh};
    return ($in_fh, $out_fh);
}

#
# Command csv2tab and tab2csv
#

sub csv2tab{
    my ($in_fh, $out_fh) = get_fh(q/csv2tab/);
    while(<$in_fh>){
        s/,/\t/g;
        print $out_fh $_;
    }
}

sub tab2csv{
    my ($in_fh, $out_fh) = get_fh(q/tab2csv/);
    while(<$in_fh>){
        s/\t/,/g;
        print $out_fh $_;
    }
}


#
# Print min, max, sum, average etc ...
#

sub read_table{
    my $in_fh = shift;
    my %matrix;
    $matrix{num_rows} = -1;
    while(<$in_fh>){
        next if /^\s*#/ or /^\s*$/;
        $matrix{num_rows}++;
        chomp;
        my @F = split /\t/;
        if($matrix{num_rows} == 0){
            $matrix{title} = "$_\n";
            $matrix{num_cols} = scalar(@F) - 1;
            $matrix{name}->{col} = [@F];
            next;
        }
        $matrix{name}->{row}->[$matrix{num_rows}] = $F[0];
        $matrix{row}->[$matrix{num_rows}] = [@F];
    }
    return \%matrix;
}

sub apply{
    my ($cmd, $id, @num) = @_;
    if($cmd eq q/sum/){
        return sum(@num);
    }elsif($cmd eq q/max/){
        return max(@num);
    }elsif($cmd eq q/min/){
        return min(@num);
    }else{die "CMD: $cmd"}
}

sub matrix_row_process{
   my $cmd = shift;
   my ($in_fh, $out_fh) = get_fh(qq/row$cmd/);
   my $matrix = read_table($in_fh);
   for my $row (1 .. $matrix->{num_rows}){
       print $out_fh $matrix->{name}->{row}->[$row], "\t", 
             apply($cmd, @{$matrix->{row}->[$row]}), 
             "\n";
   }
}

sub rowsum{&matrix_row_process(q/sum/)}
sub rowmax{&matrix_row_process(q/max/)}
sub rowmin{&matrix_row_process(q/min/)}

sub matrix_col_process{
   my $cmd = shift;
   my ($in_fh, $out_fh) = get_fh(qq/col$cmd/);
   my $matrix = read_table($in_fh);
   for my $col (1 .. $matrix->{num_cols}){
       print $out_fh $matrix->{name}->{col}->[$col], "\t",
             apply($cmd, map{$matrix->{row}->[$_]->[$col]}(1..$matrix->{num_rows})),
             "\n";
   }
}

sub colsum{&matrix_col_process(q/sum/)}
sub colmax{&matrix_col_process(q/max/)}
sub colmin{&matrix_col_process(q/min/)}

sub matrix_process_all{
    my $cmd = shift;
    my ($in_fh, $out_fh) = get_fh($cmd);
    my $title = <$in_fh>;
    my @array;
    while(<$in_fh>){
        chomp;
        my @F = split /\t/;
        push @array, @F[1..$#F];
    }
    print $out_fh apply($cmd, @array),"\n";
    
}

sub matrix_sum{&matrix_process_all(q/sum/)}
sub matrix_max{&matrix_process_all(q/max/)}
sub matrix_min{&matrix_process_all(q/min/)}

sub matrix_size{
    my ($in_fh, $out_fh) = get_fh(qq/size/);
    my $matrix = read_table($in_fh);
    print $out_fh "Row\t", $matrix->{num_rows}, "\nColumn\t",$matrix->{num_cols},"\n";

}

#
# Command rmissing
#

sub present_missing{
    my $line = shift;
    chomp $line;
    my @F = split /\t/;
    for my $i (@F[1..$#F]){
        return 1 if $i =~ /^\s*-\s*$/;
    }
    return 0;
}

sub less_than_1{
    my $line = shift;
    chomp $line;
    my @F = split /\t/;
    for my $i (@F[1..$#F]){
        return 1 if $i < 1;
    }
    return 0;
}

sub rmissing{
    my ($in_fh, $out_fh) = get_fh(q/rmissing/);
    while(<$in_fh>){
        print and next if $. == 1; 
        next if present_missing($_);
        print $out_fh $_;
    }
}

sub rm1{
    my ($in_fh, $out_fh) = get_fh(q/rm1/);
    my $c = 0;
    while(<$in_fh>){
        $c++;
        print and next if $c == 1;
        next if less_than_1($_);
        print $out_fh $_;
    }
}

sub get_group{
    my $str = shift;
    die "String: $str" unless $str =~ /^\S+?\|(\S+)$/;
    return $1; 
}

sub by_sum{
    my ($array_ref) = shift;
    return sum(@{$array_ref}[1..$#{$array_ref}]);
}

sub get_best_obs{
    my ($matrix, @rows) = @_;
    my @sorted = sort{by_sum($matrix->{row}->[$b]) <=> 
                      by_sum($matrix->{row}->[$a])}@rows;
    my $best = $sorted[0];
    return join("\t",@{$matrix->{row}->[$best]})."\n";
}

sub groupbest{
    my ($in_fh, $out_fh) = get_fh(q/groupbest/);
    my $matrix = read_table($in_fh);
    my %groups;
    for my $row (1..$matrix->{num_rows}){
        my $id = $matrix->{name}->{row}->[$row];
        my $group = get_group($id);
        push @{$groups{$group}}, $row;
    }
    print $out_fh $matrix->{title};
    for my $group (sort {$a cmp $b} keys %groups){
        my @rows = @{$groups{$group}};
        print $out_fh get_best_obs($matrix, @rows);
    }
}

#
# Operation 
#

sub math_log{
    my $options = get_options(q/op/);
    my $in_fh = $options->{in_fh};
    my $out_fh = $options->{out_fh};
    my $expression = $options->{expression};
    my $matrix = read_table($in_fh);
    print $out_fh $matrix->{title};
    for my $row (1..$matrix->{num_rows}){
        print $out_fh $matrix->{name}->{row}->[$row];
        for my $col (1..$matrix->{num_cols}){
            my $cell = $matrix->{row}->[$row]->[$col];
            my $result = log($cell);
            print $out_fh "\t$result";
        }
        print $out_fh "\n";
    }
}
