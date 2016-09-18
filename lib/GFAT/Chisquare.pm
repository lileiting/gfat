package GFAT::Chisquare;

use Carp qw< croak >;
use List::Util qw< sum >;
use Statistics::Distributions qw< chisqrprob >;
our @ISA = qw(Exporter);
our @EXPORT = qw(chisqtest_of_lmxll chisqtest_of_nnxnp chisqtest_of_hkxhk);
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

sub chisqtest_of_lmxll{
    die unless @_ == 2;
    my ($obs1, $obs2) = @_;
    my $avg = ($obs1 + $obs2) / 2;
    return chi_squared_test(observed => [$obs1, $obs2], 
        expected => [$avg, $avg]);
}

sub chisqtest_of_nnxnp{
    die unless @_ == 2;
    my ($obs1, $obs2) = @_;
    my $avg = ($obs1 + $obs2) / 2;
    return chi_squared_test(observed => [$obs1, $obs2], 
        expected => [$avg, $avg]);
}

sub chisqtest_of_hkxhk{
    die unless @_ == 3;
    my ($obs1, $obs2, $obs3) = @_;
    my $half = ($obs1 + $obs2 + $obs3) / 2;
    my $quarter = $half / 2;
    return chi_squared_test(observed => [$obs1, $obs2, $obs3], 
        expected => [$quarter, $half, $quarter]);
}


1;
