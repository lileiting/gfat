#!/usr/bin/env perl

use warnings;
use strict;
use Carp;
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
           lmxll, nnxnp, hkxhk, efxeg, abxcd',
        filter3 => 'Perform chi square test, missing data filter, and add
           genotype codes'
    );
    &{ \&{run_action(%actions)} };
}

main unless caller;

############################################################
# Subroutines
############################################################

sub _determint_seg_type{
    croak "Two arguments required!" unless @_ == 2;
    my ($parent1, $parent2) = @_;
    my %hash;
    $hash{seg_type} = 'NA';
    $hash{genotypes} = [];
    my @genotypes = qw(./.
       0/0
       0/1 1/1
       0/2 1/2 2/2
       0/3 1/3 2/3 3/3);
    map{$hash{$_} = "--"}@genotypes;


    # nnxnp, lmxll, hkxhk
    if($parent1 eq '0/0' and $parent2 eq '0/1'){
        $hash{seg_type}            = 'nnxnp';
        $hash{genotypes}           = [qw(0/0 0/1)];
        @hash{@{$hash{genotypes}}} =  qw(nn  np);
    }
    elsif($parent1 eq '0/1' and $parent2 eq '0/0'){
        $hash{seg_type}            = 'lmxll';
        $hash{genotypes}           = [qw(0/1 0/0)];
        @hash{@{$hash{genotypes}}} =  qw(lm  ll);
    }
    elsif($parent1 eq '0/1' and $parent2 eq '0/1'){
        $hash{seg_type}            = 'hkxhk';
        $hash{genotypes}           = [qw(0/0 0/1 1/1)];
        @hash{@{$hash{genotypes}}} =  qw(hh  hk  kk);
    }

    # efxeg, six combinations
    elsif($parent1 eq '0/1' and $parent2 eq '0/2'){
        $hash{seg_type}            = 'efxeg';
        $hash{genotypes}           = [qw(0/1 0/2 0/0 1/2)];
        @hash{@{$hash{genotypes}}} =  qw(ef  eg  ee  fg);
    }
    elsif($parent1 eq '0/1' and $parent2 eq '1/2'){
        $hash{seg_type}            = 'efxeg';
        $hash{genotypes}           = [qw(0/1 1/2 1/1 0/2)];
        @hash{@{$hash{genotypes}}} =  qw(ef  eg  ee  fg);
    }
    elsif($parent1 eq '0/2' and $parent2 eq '0/1'){
        $hash{seg_type}            = 'efxeg';
        $hash{genotypes}           = [qw(0/2 0/1 0/0 1/2)];
        @hash{@{$hash{genotypes}}} =  qw(ef  eg  ee  fg);
    }
    elsif($parent1 eq '0/2' and $parent2 eq '1/2'){
        $hash{seg_type}            = 'efxeg';
        $hash{genotypes}           = [qw(0/2 1/2 2/2 0/1)];
        @hash{@{$hash{genotypes}}} =  qw(ef  eg  ee  fg);
    }
    elsif($parent1 eq '1/2' and $parent2 eq '0/1'){
        $hash{seg_type}            = 'efxeg';
        $hash{genotypes}           = [qw(1/2 0/1 1/1 0/2)];
        @hash{@{$hash{genotypes}}} =  qw(ef  eg  ee  fg);
    }
    elsif($parent1 eq '1/2' and $parent2 eq '0/2'){
        $hash{seg_type}            = 'efxeg';
        $hash{genotypes}           = [qw(1/2 0/2 2/2 0/1)];
        @hash{@{$hash{genotypes}}} =  qw(ef  eg  ee  fg);
    }

    # abxcd, six combinations
    elsif($parent1 eq '0/1' and $parent2 eq '2/3'){
        $hash{seg_type}            = 'abxcd';
        $hash{genotypes}           = [qw(0/2 1/3 1/2 1/3)];
        @hash{@{$hash{genotypes}}} =  qw(ac  ad  bc  bd);
    }
    elsif($parent1 eq '0/2' and $parent2 eq '1/3'){
        $hash{seg_type}            = 'abxcd';
        $hash{genotypes}           = [qw(0/1 0/3 1/2 2/3)];
        @hash{@{$hash{genotypes}}} =  qw(ac  ad  bc  bd);
    }
    elsif($parent1 eq '0/3' and $parent2 eq '1/2'){
        $hash{seg_type}            = 'abxcd';
        $hash{genotypes}           = [qw(0/1 0/2 1/3 2/3)];
        @hash{@{$hash{genotypes}}} =  qw(ac  ad  bc  bd);
    }
    elsif($parent1 eq '1/2' and $parent2 eq '0/3'){
        $hash{seg_type}            = 'abxcd';
        $hash{genotypes}           = [qw(0/1 1/3 0/2 2/3)];
        @hash{@{$hash{genotypes}}} =  qw(ac  ad  bc  bd);
    }
    elsif($parent1 eq '1/3' and $parent2 eq '0/2'){
        $hash{seg_type}            = 'abxcd';
        $hash{genotypes}           = [qw(0/1 1/2 0/3 2/3)];
        @hash{@{$hash{genotypes}}} =  qw(ac  ad  bc  bd);
    }
    elsif($parent1 eq '2/3' and $parent1 eq '0/1'){
        $hash{seg_type}            = 'abxcd';
        $hash{genotypes}           = [qw(0/2 1/2 0/3 1/3)];
        @hash{@{$hash{genotypes}}} =  qw(ac  ad  bc  bd);
    }
    else{
        return %hash;
    }

    return %hash;
}

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

sub filter3{
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
                print '##INFO=<ID=SEGT,Number=0,Type=String,Description='.
                      '"Segregation type: lmxll, nnxnp, hkxhk, efxeg, abxcd">'.
                      "\n";
                print '##INFO=<ID=GTN,Number=11,Type=Integer,Description='.
                      '"Number of genotypes for: ./., 0/0, 0/1, 1/1, 0/2, 1/2, '.
                      '2/2, 0/3, 1/3, 2/3, 3/3">'."\n";
                print '##INFO=<ID=PCHI,Number=1,Type=Float,Description='.
                      '"P value of chi square test">'."\n";
                print '##FORMAT=<ID=GTCD,Number=0,Type=String,Description='.
                      '"Genotype codes: lm, ll, nn, np, hh, hk, kk, ef, '.
                      'eg, ee, fg, ac, bd, bc, bd">'."\n";
                print;
                next;
            }
            chomp;
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
            my %hash = _determint_seg_type(@parents_GT);
            my @all_genotypes = qw(./.
                0/0
                0/1 1/1
                0/2 1/2 2/2
                0/3 1/3 2/3 3/3);
            my %progenies_GT = map{$_, 0} @all_genotypes;
            map{$progenies_GT{$_}++}@progenies_GT;
            my @seg_data = @progenies_GT{@{$hash{genotypes}}};

            # Filter by segregation types
            next if $hash{seg_type} eq 'NA';

            # Filter by missing rate
            my $valid_genotypes = sum(@seg_data);
            next if $valid_genotypes < $number_of_progenies * (1 - $missing);

            # Filter by chi square test
            my $p = chisqtest $hash{seg_type}, @seg_data;
            next if $p < $pvalue;

            # Print results
            $f[7] .= ";SEGT=$hash{seg_type};GTN=".join(",",
               @progenies_GT{@all_genotypes}).";PCHI=$p";
            $f[8] .= ':GTCD';
            my @parents_GTCD = split /x/, $hash{seg_type};
            $f[9] .= ":".$parents_GTCD[0];
            $f[10] .= ":".$parents_GTCD[1];
            for (my $i = 0; $i <= $#progenies_GT; $i++){
                $f[$i+11] .= ":".$hash{$progenies_GT[$i]};
            }

            print join("\t", @f)."\n";
        }
    }
}



__END__
