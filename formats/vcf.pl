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
            coordinates, or reverse',
        clean => 'Clean information added by the filter action',
        filter => 'Perform chi square test, missing data filter, depth filter
            and add genotype codes',
        recalculateAD => 'Re-calculate the INFO/AD tag based on the FORMAT/AD
            tag, because `bcftools merge` do not update INFO/AD by default
            (if you have no oppportunity to rerun the `bcftools merge step`).',
        sample => 'Sample 3 markers per scaffold'
    );
    &{ \&{ run_action(%actions) } };
}

main unless caller;

############################################################
# Subroutines
############################################################

#
# Convert chromsome-based coordinated to scaffold-based coordinates
#

sub chr2scaffold {
    my $args = new_action(
        -desc => 'Convert chromsome-based coordinates to scaffold-based
            coordinates, or reverse',
        -options => {
            "listfile|l=s" => 'chromsome-based coordinates to scaffold-based
                coordinates mapping dictionary. Five columns required: Chr,
                Scafold, Start on Chr, End on Chr, Strand',
            "reverse|v" => 'Reverse the convertion'
        }
    );

    my $listfile = $args->{options}->{listfile};
    my $reverse = $args->{options}->{reverse};
    die "List file is required!\n" unless $listfile;
    my %chr;
    my %scf;
    open my $list_fh, $listfile or die $!;
    while (<$list_fh>) {
        chomp;
        my ( $chr, $scaffold, $start, $end, $strand ) = split /\t/;
        push @{ $chr{$chr} }, [ $scaffold, $start, $end, $strand ];
        $scf{$scaffold} = [$chr, $start, $end, $strand] if $reverse;
    }
    close $list_fh;

    for my $fh ( @{ $args->{in_fhs} } ) {
        while (<$fh>) {
            if (not $reverse and /^##contig=<ID=(Chr\d+)/) {
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
            if($reverse){
                $chr = "\L$chr\E";
                die "CAUTION: Chromosome posoition for $chr was not defined!\n"
                    unless exists $scf{$chr};
                my ($n_chr, $n_start, $n_end, $n_strand) = @{$scf{$chr}};
                my $new_pos = $n_strand eq '-'
                  ? $n_end - $pos + 1
                  : $n_start + $pos - 1;
                print join("\t", $n_chr, $new_pos, @f[2 .. $#f]);
                next;
            }

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


#
# Clean information added by the filter action
#

sub clean {
    my $args = new_action (
        -desc => 'Clean information added by the filter action'
    );

    for my $fh ( @{ $args->{in_fhs} } ) {
        while (<$fh>) {
            if(/^#/){
                print if not ( /^##INFO=<ID=(SEGT|GTN|PCHI|MISS)/
                    or /^##FORMAT=<ID=GTCD/ );
            }
            else{
                chomp;
                my @f = split /\t/;

                my @info = _parse_info( $f[7] );
                my %info_ex = map{$_, 1} qw(SEGT GTN PCHI MISS);
                my @kept_index = grep {not exists $info_ex{$info[$_]->[0]}}
                    (0..$#info);
                $f[7] = join( ";", map{ join( "=", @{ $info[$_] } ) }
                    @kept_index );

                my @formats = split /:/, $f[8];
                my $index;
                for(my $i = 0; $i <= $#formats; $i++){
                    $index = $i and last if $formats[$i] eq 'GTCD';
                }
                print and next if not defined $index;
                splice @formats, $index, 1;
                $f[8] = join(":", @formats);
                for my $i (9..$#f){
                    my @tags = split /:/, $f[$i];
                    splice @tags, $index, 1;
                    $f[$i] = join(":", @tags);
                }
                print join("\t", @f) . "\n";
            }
        }
    }
}

#
# Determine segregation genotypes for a diploid hybrid population
#

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

    for my $key (keys %hash){
        my $r = join('/', reverse (split '/', $key));
        $hash{$r} = $hash{$key};
    }

    return %hash;
}

sub _filter_by_depth_and_gt_chisqtest{
    my ($f, $mindepth, $maxdepth, $pvalue, $stats) = @_;
    my @format = split /:/, $f->[8];
    my %index = map{$format[$_], $_}(0..$#format);
    croak "DP tag is missing!" if not exists $index{DP};
    croak "GT tag is missing!" if not exists $index{GT};
    croak "AD tag is missing!" if not exists $index{AD};
    my @samples_GT;
    for my $i (9..$#{$f}){
        my @tags = split /:/, $f->[$i];
        my $depth = $tags[$index{DP}];
        my $gt = $tags[$index{GT}];
        if($gt eq './.'){
            push @samples_GT, $gt;
            next;
        }
        my %ad_index = map{$_, 1} split /\//, $gt;
        my @ad = (split /,/, $tags[$index{AD}])[keys %ad_index];
        my $status = 0b000;
        if($mindepth > 0 and $depth < $mindepth){
            $status |= 0b100;
            $stats->{gt2miss_mindepth}++;
        }
        if( $maxdepth > 0 and $depth > $maxdepth){
            $status |= 0b010;
            $stats->{gt2miss_maxdepth}++;
        }
        if( defined $pvalue and sum(@ad) > 0 and @ad == 2 and chisqtest('1:1', @ad) < $pvalue ){
            $status |= 0b001;
            $stats->{gt2miss_chisqtest}++;
        }
        if($status > 0){
            $gt = './.';
            $stats->{gt2miss_all}++;
        }
        push @samples_GT, $gt;
    }
    return @samples_GT;
}

sub _nt_ratio_test{
    my ($info, @gt) = @_;

    my %info = _parse_info($info);
    die "AD tag is missing in `$info`" if not exists $info{AD};
    my @ad = split /,/, $info{AD};

    my %index;
    @gt = map {split /\//, $_} @gt;
    map{ $index{$_}++ }@gt;

    my @index = sort {$a <=> $b} keys %index;
    my @ratio = map{ $index{$_} }@index;

    return chisqtest(join(":", @ratio), @ad[@index]);
}

sub filter {
    my $args = new_action(
        -desc    => 'Filter VCF data',
        -options => {
            "missing|m=f" => 'Missing data rate.
                Allowed missing data =
                total number of progenies *
                missing data rate [default: 0.05]',
            "seg_ratio|P=f" => 'P-value cutoff for Chi squared
                test for segregation ratio [default: 0.05]',
            "ind_nt_ratio|M=f" => 'P-value cutoff for Chi squared
                test for nucleotide ratio of heterozygous
                genotypes, i.e. nucleotide ratio for a 0/1
                genotype must be 1:1. Recommendation: 0.05
                [default: disable]',
            "all_nt_ratio|N=f" => 'P-value cutoff for Chi squared
                test for nucleotide ratio of the locus in all
                samples, i.e. for a locus with parents genotypes
                0/0 and 0/1, nucleotide ratio for REF:ALT must be
                1:1. Recommendation: 0.05 [default: disable]',
            "mindepth|I=i" => 'Minimum depth for trusted
                genotype calls, 0: disable, [default: 4]',
            "maxdepth|X=i" => 'Maximum depth, 0: disable
                [default: 200]',
            "stats|s=s" => 'Statistics file [default: STDERR]',
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

    my $missing = $args->{options}->{missing} // 0.05;
    #my $pvalue  = $args->{options}->{pvalue}  // 0.05;
    my $mindepth = $args->{options}->{mindepth} // 4;
    my $maxdepth = $args->{options}->{maxdepth} // 200;
    my $no_codes = $args->{options}->{no_codes};
    my $no_stats = $args->{options}->{no_stats};
    my $stats    = $args->{options}->{stats};

    my $seg_ratio = $args->{options}->{seg_ratio} // 0.05;
    my $ind_nt_ratio = $args->{options}->{ind_nt_ratio};
    my $all_nt_ratio = $args->{options}->{all_nt_ratio};

    die "Missing data rate should be in the range of [0, 1]"
        unless $missing >= 0 and $missing <= 1;
    die "Depth should be integer and >=0"
        unless $mindepth >= 0 and $maxdepth >= 0;

    my $stats_fh = \*STDERR;
    if($stats){ open $stats_fh, "> $stats" or die $! }
    my %stats;

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
                  . '"Number of missing data">' . "\n";
                print '##FORMAT=<ID=GTCD,Number=1,Type=String,Description='
                  . '"Genotype codes: lm, ll, nn, np, hh, hk, kk, ef, '
                  . 'eg, ee, fg, ac, bd, bc, bd, --">' . "\n";
                print;
                next;
            }
            chomp;
            $stats{num_of_markers}++;

            # Exclude INDELs
            if(/INDEL/){
                $stats{next_by_indel}++;
                next;
            }

            my @f             = split /\t/;
            my $ALT           = $f[4];
            my @samples_GT    = _filter_by_depth_and_gt_chisqtest(
                \@f, $mindepth, $maxdepth, $ind_nt_ratio, \%stats);
            my @parents_GT    = @samples_GT[0,1];
            my %hash          = _determint_seg_type(@parents_GT);

            # Filter by segregation types
            if($hash{seg_type} eq 'NA'){
                $stats{next_by_seg_type}++;
                next;
            }

            # Filter by nucleotide depth ratio chi squared test
            if(defined $all_nt_ratio and _nt_ratio_test($f[7], @parents_GT) < $all_nt_ratio){
                $stats{next_by_nt_ratio_test}++;
                next;
            }

            my @progenies_GT  = @samples_GT[2..$#samples_GT];
            my @all_genotypes = qw(./.
              0/0
              0/1 1/1
              0/2 1/2 2/2
              0/3 1/3 2/3 3/3);
            my %progenies_GT = map { $_, 0 } @all_genotypes;
            map { $progenies_GT{$_}++ } @progenies_GT;
            my @seg_data = @progenies_GT{ @{ $hash{genotypes} } };

            # Filter by missing rate
            my $missing_genotypes = $number_of_progenies - sum(@seg_data);
            if($missing_genotypes > $number_of_progenies * $missing){
                $stats{next_by_missing_rate}++;
                next;
            }

            # Filter by segregation ratio chi squared test
            my $p = chisqtest($hash{seg_type}, @seg_data);
            if($p < $seg_ratio){
                $stats{next_by_seg_ratio}++;
                next;
            }

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
                    $hash{ $progenies_GT[$i] } //= '--';
                    $f[ $i + 11 ] .= ":" . $hash{ $progenies_GT[$i] };
               }
            }
            $stats{num_of_good_markers}++;
            print join( "\t", @f ) . "\n";
        }
    }
    printf STDERR "Number of total markers: %d\n"
      . "Number of low quality genotypes: %d\n"
      . "  Number of low quality genotypes with lower depth: %d\n"
      . "  Number of low quality genotypes with higher depth: %d\n"
      . "  Number of low quality genotypes with biased nt ratio: %d\n"
      . "Excluded INDELs: %d\n"
      . "Markers filtered by segregation type: %d\n"
      . "Markers filtered by nt ratio test: %d\n"
      . "Markers filtered by missing rate: %d\n"
      . "Markers filtered by segregation ratio: %d\n"
      . "Final good markers: %d\n" ,
      map{$_ // 0} @stats{qw/num_of_markers
          gt2miss_all gt2miss_mindepth gt2miss_maxdepth gt2miss_chisqtest
          next_by_indel next_by_seg_type next_by_nt_ratio_test
          next_by_missing_rate next_by_seg_ratio
          num_of_good_markers/};
}

#
# Sample markers
#

sub _print_markers{
    my ($outformat, $data_ref, $scaffold, @positions) = @_;
    if($outformat =~ /joinmap/i){
        for my $pos (@positions){
            my @f = @{$data_ref->{$scaffold}->{$pos}};
            print join ("\t", $scaffold . '-' .$pos,
                    map{my @tmp = split /:/; $tmp[-1]}
                    @f[9..$#f])
                    . "\n";
        }
    }
    elsif($outformat =~ /vcf/i){
        for my $pos (@positions){
            print join("\t",  @{$data_ref->{$scaffold}->{$pos}}) . "\n";
        }
    }
    elsif($outformat =~ /tassel/){
        for my $pos (@positions){
            my @f = @{$data_ref->{$scaffold}->{$pos}};
            print join("\t", @f[0..7],
                map{my @tmp = split /:/; $tmp[0]}
                @f[8..$#f]) . "\n";
        }
    }
    else{
        die;
    }
}

sub _sample_markers_from_a_scaffold{
    my $outformat = shift;
    my $data_ref  = shift;
    my @scaffolds = keys %$data_ref;
    die unless @scaffolds == 1;
    my $scaffold = shift @scaffolds;
    my @positions = sort {$a <=> $b} keys %{$data_ref->{$scaffold}};

    if(@positions <= 3){
        _print_markers($outformat, $data_ref, $scaffold, @positions);
    }
    else{
        my %missing;
        my %count;
        for my $pos (@positions){
            die unless exists $data_ref->{$scaffold}->{$pos};
            my @f = @{$data_ref->{$scaffold}->{$pos}};
            my %info = _parse_info( $f[7] );
            die "CAUTION: Could not locate the MISS tag! -- $f[7]"
                unless exists $info{MISS};
            $missing{$pos} = $info{MISS};
            $count{$info{MISS}}++;
        }
        my %allowed = (0 => 1);
        my $sum;
        for my $n (sort{$a <=> $b}keys %count){
            $sum += $count{$n};
            $allowed{$n}++;
            last if $sum > 3;
        }

        my @allowed_positions = grep
            { exists $allowed{ $missing{$_} } } @positions;

        _print_markers($outformat, $data_ref, $scaffold,
            @allowed_positions[ 0, int($#allowed_positions / 2),
                                $#allowed_positions ] );
    }

    delete $data_ref->{$scaffold};

}

sub sample {
    my $args = new_action(
        -desc => 'Sample 3 markers from each scaffolds. Assume
            the VCF data was sorted based on position',
        -options => {
            "INDEL|I" => 'Include INDEL data [default: disable]',
            "type|t=s@" => 'Only process specified types: lmxll, nnxnp,
                hkxhk, efxeg, abxcd. Multiple types are allowed.
                [default: lmxll]',
            "outformat|O=s" => 'Output format: VCF, joinmap, TASSEL
                [default: joinmap]'
        }
    );

    my $indel = $args->{options}->{indel};
    my @types = $args->{options}->{type}
        ? split(/,/, join(",", @{$args->{options}->{type}}))
        : qw(lmxll);
    my $type = join('|', @types);
    my $outformat = $args->{options}->{outformat} // 'joinmap';
    die "CAUTION: Output format is unsupported: $outformat"
        unless $outformat =~ /joinmap|vcf|tassel/i;

    my %data;
    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            # Print header if the outformat is VCF or TASSEL
            if(/^#/){
                if($outformat =~ /vcf|tassel/i){
                    print $_;
                    next;
                }
                elsif($outformat =~ /joinmap/){
                    next;
                }
                else{
                    die;
                }
            }

            next if /INDEL/ and not $indel;

            chomp;
            my @f = split /\t/;
            my ($scaffold, $pos) = @f[0,1];
            my $info = $f[7];
            next unless $info =~ /$type/;

            if (keys %data > 0 and not exists $data{$scaffold}){
                _sample_markers_from_a_scaffold($outformat, \%data);
            }

            die "CAUTION: GTCD is expected in the end of $f[8]"
                unless $f[8] =~ /GTCD$/;
            $data{$scaffold}->{$pos} = [@f];
        }
    }
}

#----------------------------------------------------------#

sub _parse_info{
    my $info = shift;
    my %hash;
    my @fields = split /;/;
    for my $field (@fields){
        if($field =~ /^(\S+)=(\S+)$/){
            $hash{$1} = $2;
        }
        else{
            $hash{$field} = undef;
        }
    }
    return %hash;
}

sub _tag_index_in_format{
    my $format = shift;
    my $tag = shift;
    croak "Tag format incorrect!" unless $tag =~ /[A-Z0-9]/;
    my @tags = split /:/, $format;
    for my $i (0..$#tags){
        return $i if $tags[$i] eq $tag;
    }
    die "CAUTION: Could not locate `$tag` in `$format`!";
}

sub _retrieve_tag_by_index{
    my ($sample, $i) = @_;
    my @tags = split(/:/, $sample);
    my $tag = $tags[$i];
    return () if $tag eq '.';
    if($tag =~ /,/){
        return map{$_ eq '.' ? 0 : $_} split(/,/, $tag);
    }
    else{
        return ($tag);
    }
}

sub recalculateAD{
    my $args = new_action(
        -desc => 'Re-calculate the INFO/AD tag based on the FORMAT/AD
            tag, because `bcftools merge` do not update INFO/AD by default
            (if you do not want to rerun the `bcftools merge step`).'
    );

    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            print and next if /^#/;
            chomp;
            my @f = split(/\t/);
            my %info = _parse_info( $f[7] );
            my $i = _tag_index_in_format( $f[8], 'AD' );
            my @info_AD;
            for my $sample (@f[9..$#f]){
                my @AD = _retrieve_tag_by_index($sample, $i);
                next if @AD == 0;
                for my $j (0..$#AD){
                    $info_AD[$j] += $AD[$j];
                }
            }
            if(@info_AD){
                my $new_AD = join(",", @info_AD);
                unless($f[7] =~ s/AD=[^=;]+/AD=$new_AD/){
                    $f[7] .= "AD=$new_AD";
                }
            }
            print join("\t", @f) . "\n";
        }
    }
}

__END__
