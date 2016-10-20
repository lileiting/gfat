#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::Chisquare;

#print GFAT::Chisquare->chi_squared_test(
#  observed => [16, 5, 9, 7, 6, 17],
#  expected => [(10) x 6]), "\n";

#print GFAT::Chisquare->chi_squared_test(observed => [60,80], expected => [70,70]),"\n";

print chisqtest('lmxll', 60, 80), "\n";
print chisqtest('nnxnp', 60, 80), "\n";
print chisqtest('hkxhk', 30, 80, 40), "\n";
print chisqtest('nnxnp', 60, 100), "\n";
print chisqtest('lmxll', 40, 100), "\n";
print chisqtest('lmxll', 30, 100), "\n";
print chisqtest('efxeg', 40, 50, 60, 30), "\n";
print chisqtest('abxcd', 30, 50, 20, 55), "\n";

print chisqtest('abxcde', 30, 50, 20, 55), "\n";

