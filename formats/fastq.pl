#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw(max);
use File::Basename;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;


our $in_desc = '<fastq|fastq.gz> [<fastq|fastq.gz> ...]';

sub main {
    my %actions = (
        polyA => 'Detect polyA',
        trimT => 'trim poly T',
        Tlength => 'length of poly T'
    );

    &{ \&{ run_action( %actions )} };
}

############################################################

sub trimT {
    my $args = new_action(
        -desc => 'Trim 5\'end poly T nucleotides',
        -options => {
            "min_length|I=i" => 'Minimum length of trimmed sequences
                              [default: 16]',
            "prefix|p=s" => "Set 5' end adapter sequences before PolyT_5prime
                            [default: ]"
        }
    );

    my $min_length = $args->{options}->{min_length} // 16;

    for my $i (0 .. $#{$args->{infiles}} ){
        my $infile = $args->{infiles}->[$i];
        my $fh = $args->{in_fhs}->[$i];

        warn "Processing $infile ...\n";
        #my ($prefix) = ($infile =~ /^(.+)\.fastq.gz$/);
        my $prefix = basename $infile, ".fastq.gz";
        my $outfile = $prefix . ($trimA ? '-trimA' : '-trimT')
            . ($trim3 ? '-both_ends' : '') . '.fastq.gz';
        warn "Writing results to $outfile ...\n";
        open my $out_fh, "| gzip > $outfile" or die $!;
        while( my $line1 = <$fh>){
            my $seqstr = <$fh>;
            my $line3 = <$fh>;
            my $line4 = <$fh>;
            chomp $seqstr;
            chomp $line4;
            my $seqlen = length $seqstr;
            my ($heading) = $trimA ?
                  ($seqstr =~ /^(A+)/)
                : ($seqstr =~ /^(T+)/);
            my $len1 = length ($heading  // '');
            unless($trim3){
                next unless $seqlen - $len1 >= $min_length;
                print $out_fh $line1, (substr $seqstr, $len1), "\n",
                      $line3, (substr $line4, $len1), "\n";
            }
            else{
                my ($tailing) = $trimA ?
                      ($seqstr =~ /(A+)$/)
                    : ($seqstr =~ /(T+)$/);
                my $len2 = length ($tailing // '');
                next unless $seqlen - $len1 - $len2 >= $min_length;
                print $out_fh $line1,
                    (substr $seqstr, $len1, $seqlen - $len1 - $len2), "\n",
                    $line3,
                    (substr $line4, $len1, $seqlen - $len1 - $len2), "\n";
            }
        }
    }

}

sub Tlength {
    my $args = new_action(
        -desc => 'Statistics of the length of Ts',
        -options => {
            "percentage|c" => 'Output reads percentage, rather than
                               reads number'
        }
    );

    my $percentage = $args->{options}->{percentage};

    my %data;
    my %number;
    for my $i (0 .. $#{$args->{infiles}}){
        my $infile = $args->{infiles}->[$i];
        my $fh = $args->{in_fhs}->[$i];
        while(my $line1 = <$fh>){
            my $line2 = <$fh>;
            my $line3 = <$fh>;
            my $line4 = <$fh>;
            $data{$infile}->{total_reads}++;
            my $seqstr = $line2;
            chomp $seqstr;
            if($seqstr =~ /^(T+|A+)/){
                my $motif = $1;
                my $nt = substr $motif, 0, 1;
                my $length = length $motif;
                $number{$length}++;
                $data{$infile}->{$nt}->{$length}++;
            }
        }
    }

    my @files = sort { $a cmp $b } keys %data;
    my $max = max(keys %number);
    print join("\t", 'Length',
        (map { "T:$_" } @files),
        (map { "A:$_" } @files) ), "\n";
    for my $n ( 1 .. $max ){
        print join("\t", $n,
            (map{ $percentage ? ( $data{$_}->{T}->{$n} // 0 ) /
                $data{$_}->{total_reads} * 100
                 : ($data{$_}->{T}->{$n} // 0 ) } @files),
            (map{ $percentage ? ( $data{$_}->{A}->{$n} // 0 ) /
                $data{$_}->{total_reads} * 100
                 : ($data{$_}->{A}->{$n} // 0 ) } @files)
        ), "\n";
    }
}


sub polyA {
    my $args = new_action(
        -desc => 'Detect poly A',
        -options => {
            "min|I=i" => 'Minimum length of Poly A/T [default: 3]'
        }
    );

    my $min = $args->{options}->{min} // 3;

    my %count;

    for my $i (0 .. $#{$args->{infiles}}){
        my $infile = $args->{infiles}->[$i];
        my $fh = $args->{in_fhs}->[$i];
        while(my $line1 = <$fh>){
            my $line2 = <$fh>;
            my $line3 = <$fh>;
            my $line4 = <$fh>;
            $count{$infile}->{total_reads}++;
            chomp $line2;
            my $seqstr = $line2;
            my $n = 0;
            if($seqstr =~ /^A{$min,}/){
                $count{$infile}->{"PolyA_5prime"}++;
            }
            elsif($seqstr =~ /^T{$min,}/){
                $count{$infile}->{"PolyT_5prime"}++;
            }

            if($seqstr =~ /A{$min,}$/){
                $count{$infile}->{"PolyA_3prime"}++;
            }
            elsif($seqstr =~ /T{$min,}$/){
                $count{$infile}->{"PolyT_3prime"}++;
            }
        }
    }

    print join(",", qw(File
        total_reads
        PolyA_5prime %
        PolyT_5prime %
        PolyA_3prime %
        PolyT_3prime %

        )), "\n";
    for my $file (sort {$a cmp $b} keys %count){
        printf "%s,%d,%d,%.2f,%d,%.2f,%d,%.2f,%d,%.2f\n",
            $file,
            $count{$file}->{total_reads},
            $count{$file}->{PolyA_5prime},
            $count{$file}->{PolyA_5prime} / $count{$file}->{total_reads} * 100,
            $count{$file}->{PolyT_5prime},
            $count{$file}->{PolyT_5prime} / $count{$file}->{total_reads} * 100,
            $count{$file}->{PolyA_3prime},
            $count{$file}->{PolyA_3prime} / $count{$file}->{total_reads} * 100,
            $count{$file}->{PolyT_3prime},
            $count{$file}->{PolyT_3prime} / $count{$file}->{total_reads} * 100
            ;
    }
}

main unless caller;

__END__
