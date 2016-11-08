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
        clean => 'Clean information added by the filter action',
        filter => 'Perform chi square test, missing data filter, depth filter
            and add genotype codes',
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

                my @info = map { [ split /=/ ] } ( split /;/, $f[7] );
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
        if( sum(@ad) > 0 and @ad == 2 and chisqtest('1:1', @ad) < $pvalue ){
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

    my %info = split /[;=]/, $info;
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
            "pvalue|p=f" => 'P-value cutoff for Chi square test.
                This script will test segregation ratio,
                nucleotide depth ratio in individual genotypes and
                all samples [default: 0.05]',
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
    my $pvalue  = $args->{options}->{pvalue}  // 0.05;
    my $mindepth = $args->{options}->{mindepth} // 4;
    my $maxdepth = $args->{options}->{maxdepth} // 200;
    my $no_codes = $args->{options}->{no_codes};
    my $no_stats = $args->{options}->{no_stats};
    my $stats    = $args->{options}->{stats};


    die "Missing data rate should be in the range of [0, 1]"
        unless $missing >= 0 and $missing <= 1;
    die "P value should be in the range of [0, 1]"
        unless $pvalue >= 0 and $pvalue <= 1;
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
                \@f, $mindepth, $maxdepth, $pvalue, \%stats);
            my @parents_GT    = @samples_GT[0,1];
            my %hash          = _determint_seg_type(@parents_GT);

            # Filter by segregation types
            if($hash{seg_type} eq 'NA'){
                $stats{next_by_seg_type}++;
                next;
            }

            # Filter by nucleotide depth ratio chi squared test
            if(_nt_ratio_test($f[7], @parents_GT) < $pvalue){
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

            # Filter by chi square test
            my $p = chisqtest($hash{seg_type}, @seg_data);
            if($p < $pvalue){
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
            my %info = map{split /=/} split /;/, $f[7];
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

__END__
