#!/usr/bin/env perl

use warnings;
use strict;
use Text::Abbrev;

sub main{
    my %subcmd = abbrev qw(cut num isct grep);
    if(`which tabtk`){
        $ARGV[0] = $subcmd{$ARGV[0]} if @ARGV > 0;
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
