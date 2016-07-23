#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use JSON;
use Data::Dumper;

sub view{
    my $args = new_action(
        -desc => 'view JSON'
    );
    my $json_text;
    for my $fh (@{$args->{in_fhs}}){
        local undef $/;
        $_ = <$fh>;
        $json_text .= $_;
    }
    my  $perl_scalar = from_json($json_text);
    print Dumper($perl_scalar);

}

sub main{
    my %actions = (
        view  => 'view JSON data',
    );
    &{\&{run_action(%actions)}};
}

main unless caller;

__END__
