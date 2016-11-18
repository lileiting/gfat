#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;

sub main{
    my %actions = (
        config => 'Print R configure variables'
    );

    &{ \&{ run_action(%actions)} };
}

sub config {
    system(q{R CMD config | grep '^  [A-Z_]' | perl -pe 's/^\s+(\w+)(, (\w+))?.*$/$1\n$3\n/' | grep -v '^$' | perl -pe 'chomp; s/^/echo $_=\$(R CMD config /;s/$/\)\n/' | sh});

}

main unless caller;

__END__

