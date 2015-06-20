#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub usage{
    print <<USAGE;

  $FindBin::Script CMD NUM

    d2h | dec => hex
    d2o | dec => oct
    d2b | dec => bin

    h2d | hex => dec
    h2o | hex => oct
    h2b | hex => bin

    o2h | oct => hex
    o2d | oct => dec
    o2b | oct => bin

    b2h | bin => hex
    b2d | bin => dec
    b2o | bin => oct

USAGE
    exit;
}

sub main{
    usage unless @ARGV == 2;
    my ($cmd, $num) = @ARGV;
    if(    $cmd eq q/d2h/ ){ printf qq|%X\n|, int($num) }
    elsif( $cmd eq q/d2o/ ){ printf qq|%o\n|, int($num) }
    elsif( $cmd eq q/d2b/ ){ printf qq|%b\n|, int($num) }

    elsif( $cmd eq q/h2d/ ){ printf qq|%d\n|, hex($num) }
    elsif( $cmd eq q/h2o/ ){ printf qq|%o\n|, hex($num) }
    elsif( $cmd eq q/h2b/ ){ printf qq|%b\n|, hex($num) }

    elsif( $cmd eq q/o2h/ ){ printf qq|%X\n|, oct($num) }
    elsif( $cmd eq q/o2d/ ){ printf qq|%d\n|, oct($num) }
    elsif( $cmd eq q/o2b/ ){ printf qq|%b\n|, oct($num) }

    elsif( $cmd eq q/b2h/ ){ printf qq|%X\n|, oct(qq|0b$num|) }
    elsif( $cmd eq q/b2d/ ){ printf qq|%d\n|, oct(qq|0b$num|) }
    elsif( $cmd eq q/b2o/ ){ printf qq|%o\n|, oct(qq|0b$num|) }

    else{die "Unrecognized command: $cmd!\n"}
}

main() unless caller
