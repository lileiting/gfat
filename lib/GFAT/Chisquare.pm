package GFAT::Chisquare;

use warnings;
use strict;
use Carp qw< croak >;
use List::Util qw< sum >;
use Statistics::Distributions qw< chisqrprob >;
our @ISA = qw(Exporter);
our @EXPORT = qw(chisqtest);
our @EXPORT_OK = @EXPORT;

sub chi_squared_test {
    # The subroutine was copied from 
    # http://stackoverflow.com/questions/21204733/a-better-chi-square-test-for-perl
    my %args = @_;
    my $observed = delete $args{observed} // croak q(Argument "observed" required);
    my $expected = delete $args{expected} // croak q(Argument "expected" required);
    @$observed == @$expected or croak q(Input arrays must have same length);

    my $chi_squared = sum map {
       ($observed->[$_] - $expected->[$_])**2 / $expected->[$_];
    } 0 .. $#$observed;
    my $degrees_of_freedom = @$observed - 1;
    my $probability = chisqrprob($degrees_of_freedom, $chi_squared);
    return $probability;
}

#say chi_squared_test
#  observed => [16, 5, 9, 7, 6, 17],
#  expected => [(10) x 6];

sub chisqtest {
    my $seg_type = shift;
    my @obs = @_;
    croak q(Two numbers required for lmxll and nnxnp) 
        if ($seg_type eq 'lmxll' or $seg_type eq 'nnxnp') and not @obs == 2;
    croak q(Three numbers required for hkxhk) 
        if $seg_type eq 'hkxhk' and not @obs == 3;
    croak q(Four numbers required for efxeg and abxcd) 
        if ($seg_type eq 'efxeg' or $seg_type eq 'abxcd') and not @obs == 4;

    my $half = sum(@obs) / 2;
    my $quarter = $half / 2;

    if($seg_type eq 'lmxll' or $seg_type eq 'nnxnp'){
        return chi_squared_test(
            observed => [@obs],
            expected => [$half, $half]
        );
    }
    elsif($seg_type eq 'hkxhk'){
        return chi_squared_test(
            observed => [@obs],
            expected => [$quarter, $half, $quarter]
        );
    }
    elsif($seg_type eq 'efxeg' or $seg_type eq 'abxcd'){
        return chi_squared_test(
            observed => [@obs],
            expected => [$quarter, $quarter, $quarter, $quarter]
        );
    }
    else{
        croak qq(Wrong segregation type: $seg_type! 
            Supported segregation types are lmxll, 
            nnxnp, hkxhk, efxeg and abxcd);
    }
}

1;
