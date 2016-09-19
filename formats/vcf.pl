#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use List::Util qw(sum);
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use GFAT::Chisquare;
our $in_desc = '<in.vcf|in.vcf.gz>';

sub main{
    my %actions = (
        filter  => 'Filter VCF data',
        filter2 => 'Perform chi square test for five segregation types:
           lmxll, nnxnp, hkxhk, efxeg, abxcd'
    );
    &{ \&{run_action(%actions)} };
}

main unless caller;

sub filter{
    my $args = new_action(
        -desc => 'Filter VCF data',
        -options => {
            "missing|m=f" => 'Missing data rate.
                Allowed missing data =
                total number of progenies *
                missing data rate [default: 0.1]'
        }
    );

    my $missing = $args->{options}->{missing} // 0.1;

    for my $fh (@{$args->{in_fhs}}){
        my $number_of_progenies;
        while(<$fh>){
           print and next if /^##/;
           if(/^#[^#]/){
              # First two samples are parents
              my @f = split /\t/;
              $number_of_progenies = scalar(@f) - 9 - 2;
              print;
              next;
           }
           my @f = split /\t/;
           my @parents = @f[9,10];
           my @progenies = @f[11..$#f];
           # Do not allow missing data in parents
           next if $parents[0] =~ m{\./\.} or $parents[1] =~ m{\./\.};
           my $number_of_missing = 0;
           for my $progeny (@progenies){
               $number_of_missing++ if $progeny =~ m{\./\.};
           }
           $number_of_missing > $number_of_progenies * $missing ? next : print;
        }
    }
}

sub filter2{
    my $args = new_action(
        -desc => 'Filter VCF data',
        -options => {
            "missing|m=f" => 'Missing data rate.
                Allowed missing data =
                total number of progenies *
                missing data rate [default: 0.1]',
            "pvalue|p=f" => 'P-value cutoff for Chi square test
                [default: 0.05]'
        }
    );

    my $missing = $args->{options}->{missing} // 0.1;
    my $pvalue = $args->{options}->{pvalue} // 0.05;

    for my $fh (@{$args->{in_fhs}}){
        my $number_of_progenies;
        while(<$fh>){
           print and next if /^##/;
           if(/^#[^#]/){
              # First two samples are parents
              my @f = split /\t/;
              $number_of_progenies = scalar(@f) - 9 - 2;
              print '##INFO=<ID=SEGT,Number=0,Type=Flag,Description='.
                    '"Segregation type: lmxll, nnxnp, hkxhk, efxeg, abxcd">'.
                    "\n";
              print '##INFO=<ID=GTN,Number=11,Type=Integer,Description='.
                    '"Number of genotypes for: ./., 0/0, 0/1, 1/1, 0/2, 1/2, '.
                    '2/2, 0/3, 1/3, 2/3, 3/3">'."\n";
              print '##INFO=<ID=PCHI,Number=1,Type=Float,Description='.
                    '"P value of chi square test">'."\n";
              print;
              next;
           }
           my @f = split /\t/;
           my $ALT = $f[4];
           my @parents = @f[9,10];
           my @progenies = @f[11..$#f];
           # Do not allow missing data in parents
           # next if $parents[0] =~ m{\./\.} or $parents[1] =~ m{\./\.};
           #my $number_of_missing = 0;
           #for my $progeny (@progenies){
           #   $number_of_missing++ if $progeny =~ m{\./\.};
           #}
           #$number_of_missing > $number_of_progenies * $missing ? next : print;
           my @parents_GT = map{(split /:/)[0]} @parents;
           my @progenies_GT = map{(split /:/)[0]} @progenies;

           my $number_of_alleles = () = $ALT =~ /,/g;
           $number_of_alleles++;
           my $seg_type;
           my ($p1, $p2) = @parents_GT;
           my @all_genotypes = qw(./.
              0/0
              0/1 1/1
              0/2 1/2 2/2
              0/3 1/3 2/3 3/3);
           my %progenies_GT = map{$_, 0} @all_genotypes;
           map{$progenies_GT{$_}++}@progenies_GT;
           my $p;
           my $expected_alleles;
           my @expected_GT;
           if($p1 eq '0/1' and $p2 eq '0/0'){
               $seg_type = 'lmxll';
               $expected_alleles =  2;
               @expected_GT = qw(0/0 0/1);
           }
           elsif($p1 eq '0/0' and $p2 eq '0/1'){
               $seg_type = 'nnxnp';
               $expected_alleles =  2;
               @expected_GT = qw(0/0 0/1);
           }
           elsif($p1 eq '0/1' and $p2 eq '0/1'){
               $seg_type = 'hkxhk';
               $expected_alleles =  2;
               @expected_GT = qw(0/0 0/1 1/1);
           }
           elsif($p1 eq '0/1' and $p2 eq '0/2' or $p1 eq '0/2' and $p1 eq '0/1'){
               $seg_type = 'efxeg';
               $expected_alleles =  3;
               @expected_GT = qw(0/0 0/1 0/2 1/1);
           }
           elsif($p1 eq '0/1' and $p2 eq '2/3'){
               $seg_type = 'abxcd';
               $expected_alleles =  4;
               @expected_GT = qw(0/2 0/3 1/2 1/3);
           }
           elsif($p1 eq '0/2' and $p2 eq '1/3'){
               $seg_type = 'abxcd';
               $expected_alleles =  4;
               @expected_GT = qw(0/1 0/3 1/2 2/3);
           }
           elsif($p1 eq '0/3' and $p2 eq '1/2'){
               $seg_type = 'abxcd';
               $expected_alleles = 4;
               @expected_GT = qw(0/1 0/2 1/3 2/3);
           }
           else{next}

           next if $number_of_alleles > $expected_alleles;
           my $valid_GT = sum(@progenies_GT{@expected_GT});
           next if $number_of_progenies - $valid_GT >
               $number_of_progenies * $missing;
           $p = chisqtest $seg_type, @progenies_GT{@expected_GT};
           next if $p < $pvalue;
           $f[7] .= ";SEGT=$seg_type;GTN=".join(",",
               map{$progenies_GT{$_}}@all_genotypes).";PCHI=$p";
           print join("\t", @f);
        }
    }
}


__END__
