#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;

sub main_usage{
    print << "usage";

USAGE
    $FindBin::Script NUM

usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $num = shift @ARGV;
    main_usage unless $num >= 1;
    my @input = (1..$num);
    arrangement(@input);
}

main() unless caller;

############################################################

sub arrangement{
    _arrangement(0, @_);
}

my @pre = ();
sub _arrangement{
    my ($level, @a) = @_;
    if(@a == 1){
        print join(",", @pre, @a),"\n";
    }
    elsif(@a > 1){
        for (my $i = 0; $i <= $#a; $i++){
            my @tmp = @a;
            my $first = splice(@tmp,$i,1);
            $pre[$level] = $first;
            _arrangement($level+1, @tmp);
        }
    }
    else{
        die "CAUTION: Input array is empty!\n";
    }
}

__END__
