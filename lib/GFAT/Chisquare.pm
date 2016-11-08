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

    map{ croak q(Illegal division by zero: ).join(",", @$expected) if $_ == 0 }@$expected;
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
    my @observed = @_;

    # lmxll, nnxnp, hkxhk, efxeg, abxcd
    my %known_types = (
        lmxll => '1:1',
        nnxnp => '1:1',
        hkxhk => '1:2:1',
        efxeg => '1:1:1:1',
        abxcd => '1:1:1:1'
    );

    $seg_type = $known_types{$seg_type} if exists $known_types{$seg_type};
    croak "Wrong segration ratio/type: `$seg_type`! Allowed segregation ratio format: NUM(:NUM)+, or known types(" .
        join(",", sort {$a cmp $b} keys %known_types). ")"
        unless $seg_type =~ /^\d+(\.\d+)?(:\d+(\.\d+)?)+$/;

    my @ratio = split /:/, $seg_type;
    croak qq(Number of observations were not consistent with $seg_type)
        unless scalar( @ratio ) == scalar( @observed );
    map{croak qq(Ratio must be a positive number) 
        unless /^\d+(\.\d+)?$/ }@ratio;
    my $sum_of_ratio = sum( @ratio );
    my $sum_of_obs   = sum( @observed   );
    my @expected = map{ $_ / $sum_of_ratio * $sum_of_obs } @ratio;
    return chi_squared_test(
        observed => [ @observed ],
        expected => [ @expected ]
    );
}

1;
