#!/usr/bin/env perl

use warnings;
use strict;

sub main{
    if(`which tabtk`){
        system("tabtk @ARGV");
    }
    else{
        warn "WARNING: tabtk was not installed in this computer!\n";
        warn "    For Mac OS, try:\n";
        warn "        brew install homebrew/science/tabtk\n";
        warn "    Source code of tabtk: https://github.com/lh3/tabtk\n";
    }
}

main unless caller;

__END__
