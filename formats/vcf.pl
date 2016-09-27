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

sub main {
    my %actions = (
        chr2scaffold => 'Convert chromsome-based coordinates to scaffold-based
            coordinates',
        filter => 'Perform chi square test, missing data filter, and add
            genotype codes'
    );
    &{ \&{ run_action(%actions) } };
}

main unless caller;

############################################################
# Subroutines
############################################################

sub chr2scaffold {
    my $args = new_action(
        -desc => 'Convert chromsome-based coordinates to scaffold-based
            coordinates',
        -options => {
            "listfile|l=s" => 'chromsome-based coordinates to scaffold-based
                coordinates mapping dictionary. Five columns required: Chr,
                Scafold, Start on Chr, End on Chr, Strand'
        }
    );

    my $listfile = $args->{options}->{listfile};
    die "List file is required!\n" unless $listfile;
    my %chr;
    open my $list_fh, $listfile or die $!;
    while (<$list_fh>) {
        chomp;
        my ( $chr, $scaffold, $start, $end, $strand ) = split /\t/;
        push @{ $chr{$chr} }, [ $scaffold, $start, $end, $strand ];
    }
    close $list_fh;

    for my $fh ( @{ $args->{in_fhs} } ) {
        while (<$fh>) {
            if (/^##contig=<ID=(Chr\d+)/) {
                print and next if not exists $chr{$1};
                for my $array ( @{ $chr{$1} } ) {
                    my ( $scaffold, $start, $end, $strand ) = @$array;
                    my $length = $end - $start + 1;
                    print "##contig=<ID=$scaffold,length=$length>\n";
                }
                next;
            }
            print and next if /^#/;
            my @f = split /\t/;
            my ( $chr, $pos ) = @f[ 0, 1 ];
            print and next if not exists $chr{$chr};
            for my $array ( @{ $chr{$chr} } ) {
                my ( $scaffold, $start, $end, $strand ) = @$array;
                if ( $pos >= $start and $pos <= $end ) {
                    my $new_pos =
                        $strand eq '-'
                      ? $end - $pos + 1
                      : $pos - $start + 1;
                    print join( "\t", $scaffold, $new_pos, @f[ 2 .. $#f ] );
                    last;
                }
            }
        }
    }
}

sub _determint_seg_type {
    croak "Two arguments required!" unless @_ == 2;
    my ( $parent1, $parent2 ) = @_;
    my %hash;
    $hash{seg_type}  = 'NA';
    $hash{genotypes} = [];
    my @genotypes = qw(./.
      0/0
      0/1 1/1
      0/2 1/2 2/2
      0/3 1/3 2/3 3/3);
    map { $hash{$_} = "--" } @genotypes;

    # nnxnp, lmxll, hkxhk
    if ( $parent1 eq '0/0' and $parent2 eq '0/1' ) {
        $hash{seg_type}                = 'nnxnp';
        $hash{genotypes}               = [qw(0/0 0/1)];
        @hash{ @{ $hash{genotypes} } } = qw(nn  np);
    }
    elsif ( $parent1 eq '0/1' and $parent2 eq '0/0' ) {
        $hash{seg_type}                = 'lmxll';
        $hash{genotypes}               = [qw(0/1 0/0)];
        @hash{ @{ $hash{genotypes} } } = qw(lm  ll);
    }
    elsif ( $parent1 eq '0/1' and $parent2 eq '0/1' ) {
        $hash{seg_type}                = 'hkxhk';
        $hash{genotypes}               = [qw(0/0 0/1 1/1)];
        @hash{ @{ $hash{genotypes} } } = qw(hh  hk  kk);
    }

    # efxeg, six combinations
    elsif ( $parent1 eq '0/1' and $parent2 eq '0/2' ) {
        $hash{seg_type}                = 'efxeg';
        $hash{genotypes}               = [qw(0/1 0/2 0/0 1/2)];
        @hash{ @{ $hash{genotypes} } } = qw(ef  eg  ee  fg);
    }
    elsif ( $parent1 eq '0/1' and $parent2 eq '1/2' ) {
        $hash{seg_type}                = 'efxeg';
        $hash{genotypes}               = [qw(0/1 1/2 1/1 0/2)];
        @hash{ @{ $hash{genotypes} } } = qw(ef  eg  ee  fg);
    }
    elsif ( $parent1 eq '0/2' and $parent2 eq '0/1' ) {
        $hash{seg_type}                = 'efxeg';
        $hash{genotypes}               = [qw(0/2 0/1 0/0 1/2)];
        @hash{ @{ $hash{genotypes} } } = qw(ef  eg  ee  fg);
    }
    elsif ( $parent1 eq '0/2' and $parent2 eq '1/2' ) {
        $hash{seg_type}                = 'efxeg';
        $hash{genotypes}               = [qw(0/2 1/2 2/2 0/1)];
        @hash{ @{ $hash{genotypes} } } = qw(ef  eg  ee  fg);
    }
    elsif ( $parent1 eq '1/2' and $parent2 eq '0/1' ) {
        $hash{seg_type}                = 'efxeg';
        $hash{genotypes}               = [qw(1/2 0/1 1/1 0/2)];
        @hash{ @{ $hash{genotypes} } } = qw(ef  eg  ee  fg);
    }
    elsif ( $parent1 eq '1/2' and $parent2 eq '0/2' ) {
        $hash{seg_type}                = 'efxeg';
        $hash{genotypes}               = [qw(1/2 0/2 2/2 0/1)];
        @hash{ @{ $hash{genotypes} } } = qw(ef  eg  ee  fg);
    }

    # abxcd, six combinations
    elsif ( $parent1 eq '0/1' and $parent2 eq '2/3' ) {
        $hash{seg_type}                = 'abxcd';
        $hash{genotypes}               = [qw(0/2 1/3 1/2 1/3)];
        @hash{ @{ $hash{genotypes} } } = qw(ac  ad  bc  bd);
    }
    elsif ( $parent1 eq '0/2' and $parent2 eq '1/3' ) {
        $hash{seg_type}                = 'abxcd';
        $hash{genotypes}               = [qw(0/1 0/3 1/2 2/3)];
        @hash{ @{ $hash{genotypes} } } = qw(ac  ad  bc  bd);
    }
    elsif ( $parent1 eq '0/3' and $parent2 eq '1/2' ) {
        $hash{seg_type}                = 'abxcd';
        $hash{genotypes}               = [qw(0/1 0/2 1/3 2/3)];
        @hash{ @{ $hash{genotypes} } } = qw(ac  ad  bc  bd);
    }
    elsif ( $parent1 eq '1/2' and $parent2 eq '0/3' ) {
        $hash{seg_type}                = 'abxcd';
        $hash{genotypes}               = [qw(0/1 1/3 0/2 2/3)];
        @hash{ @{ $hash{genotypes} } } = qw(ac  ad  bc  bd);
    }
    elsif ( $parent1 eq '1/3' and $parent2 eq '0/2' ) {
        $hash{seg_type}                = 'abxcd';
        $hash{genotypes}               = [qw(0/1 1/2 0/3 2/3)];
        @hash{ @{ $hash{genotypes} } } = qw(ac  ad  bc  bd);
    }
    elsif ( $parent1 eq '2/3' and $parent2 eq '0/1' ) {
        $hash{seg_type}                = 'abxcd';
        $hash{genotypes}               = [qw(0/2 1/2 0/3 1/3)];
        @hash{ @{ $hash{genotypes} } } = qw(ac  ad  bc  bd);
    }
    else {
        return %hash;
    }

    return %hash;
}

sub _filter_by_mindepth{
    my ($mindepth, $f) = @_;
    my @format = split(/:/, $f->[8]);
    my %index = map{$format[$_], $_}(0..$#format);
    croak "DP tag is missing!" if not exists $index{DP};
    my @samples_GT;
    for my $i (9..$#{$f}){
        my @tags = split /:/, $f->[$i];
        my $depth = $tags[$index{DP}];
        if($tags[0] ne './.' and $depth < $mindepth){
            push @samples_GT, './.';
        }
        else{
            push @samples_GT, $tags[0];
        }
    }
    return @samples_GT;
}

sub filter {
    my $args = new_action(
        -desc    => 'Filter VCF data',
        -options => {
            "missing|m=f" => 'Missing data rate.
                Allowed missing data =
                total number of progenies *
                missing data rate [default: 0.1]',
            "pvalue|p=f" => 'P-value cutoff for Chi square test
                [default: 0.05]',
            "mindepth|I=i" => 'Minimum depth for trusted 
                genotype calls, 0: disable, [default: 3]',
            "no_codes|C" => 'Do not add genotype codes, like lm,
                ll, nn, np, hh, hk, kk, etc  
                [default: add genotype codes]',
            "no_stats|S" => 'Do not add statistics to the INFO,
                including SEGT (segregation type), 
                GTN (genotype number), and PCHI (p-value of 
                chi square test) [default: add statistics to 
                the INFO]'
        }
    );

    my $missing = $args->{options}->{missing} // 0.1;
    my $pvalue  = $args->{options}->{pvalue}  // 0.05;
    my $mindepth = $args->{options}->{mindepth} // 3;
    my $no_codes = $args->{options}->{no_codes};
    my $no_stats = $args->{options}->{no_stats};

    die "Missing data rate should be in the range of [0, 1]"
        unless $missing >= 0 and $missing <= 1;
    die "P value should be in the range of [0, 1]"
        unless $pvalue >= 0 and $pvalue <= 1;
    die "Depth should be integer and >= 0"
        unless $mindepth =~ /\d+/;

    for my $fh ( @{ $args->{in_fhs} } ) {
        my $number_of_progenies;
        while (<$fh>) {
            print and next if /^##/;
            if (/^#[^#]/) {

                # First two samples are parents
                my @f = split /\t/;
                $number_of_progenies = scalar(@f) - 9 - 2;
                print '##INFO=<ID=SEGT,Number=1,Type=String,Description='
                  . '"Segregation type: lmxll, nnxnp, hkxhk, efxeg, abxcd">'
                  . "\n";
                print '##INFO=<ID=GTN,Number=11,Type=Integer,Description='
                  . '"Number of genotypes for: ./., 0/0, 0/1, 1/1, 0/2, '
                  . '1/2, 2/2, 0/3, 1/3, 2/3, 3/3">' . "\n";
                print '##INFO=<ID=PCHI,Number=1,Type=Float,Description='
                  . '"P value of chi square test">' . "\n";
                print '##INFO=<ID=MISS,Number=1,Type=Integer,Description='
                  . '"Number of missing data">';
                print '##FORMAT=<ID=GTCD,Number=1,Type=String,Description='
                  . '"Genotype codes: lm, ll, nn, np, hh, hk, kk, ef, '
                  . 'eg, ee, fg, ac, bd, bc, bd, --">' . "\n";
                print;
                next;
            }
            chomp;
            my @f             = split /\t/;
            my $ALT           = $f[4];
            my @samples_GT    = $mindepth > 0
                 ? _filter_by_mindepth($mindepth, \@f)
                 : map { ( split /:/ )[0] } @f[9..$#f];
            my @parents_GT    = @samples_GT[0,1];
            my @progenies_GT  = @samples_GT[2..$#samples_GT];
            my %hash          = _determint_seg_type(@parents_GT);
            my @all_genotypes = qw(./.
              0/0
              0/1 1/1
              0/2 1/2 2/2
              0/3 1/3 2/3 3/3);
            my %progenies_GT = map { $_, 0 } @all_genotypes;
            map { $progenies_GT{$_}++ } @progenies_GT;
            my @seg_data = @progenies_GT{ @{ $hash{genotypes} } };

            # Filter by segregation types
            next if $hash{seg_type} eq 'NA';

            # Filter by missing rate
            my $missing_genotypes = $number_of_progenies - sum(@seg_data);
            next if $missing_genotypes > $number_of_progenies * $missing;

            # Filter by chi square test
            my $p = chisqtest $hash{seg_type}, @seg_data;
            next if $p < $pvalue;

            # Print results
            if( not $no_stats){
                $f[7] .=
                    ";SEGT=$hash{seg_type};GTN="
                  . join( ",", @progenies_GT{@all_genotypes} )
                  . ";PCHI=$p;MISS=$missing_genotypes";
            }

            if( not $no_codes ){
                $f[8] .= ':GTCD';
                my @parents_GTCD = split /x/, $hash{seg_type};
                $f[9]  .= ":" . $parents_GTCD[0];
                $f[10] .= ":" . $parents_GTCD[1];
                for ( my $i = 0 ; $i <= $#progenies_GT ; $i++ ) {
                    $f[ $i + 11 ] .= ":" . $hash{ $progenies_GT[$i] };
               }
            }

            print join( "\t", @f ) . "\n";
        }
    }
}

__END__
