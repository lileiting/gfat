#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Gfat::Cmd::Base qw(base_main get_fh close_fh);

sub actions{
    return {
        simplify => [ \&simplify, "Simplify results"],
        -description => "Process data from transmembrane motif prediction [http://www.cbs.dtu.dk/services/TMHMM/]"
    };
}

base_main(actions);

##############
# Subroutine #
##############

=head2 tmm.pl simplify

  Title    : tmm.pl simplify

  Functions: Simplify results from transmembrane motif prediction

  Usage    : tmm.pl simplify [OPTIONS]

  Options  : [-i,--input] <FILE>
             -o,--output  FILE
             -h,--help

=cut

sub simplify_topology{
    my $str = shift;
    die "CAUTION: Topology is empty!" 
        unless $str =~ /^Topology=([io\-\d]+)$/;
    $str = $1;
    return '-' if $str eq 'o' or $str eq 'o';
    $str =~ s/^[io]//;
    $str =~ s/[io]$//;
    $str =~ s/[io]/,/g;
    return $str;
}

sub simplify{
    my ($in_fh, $out_fh, $options) = get_fh(q/simplify/,
        "excel" => "Print results enclosed with =\"\" to make it as string in Excel");
    my $excel = $options->{excel};
    while(<$in_fh>){
        next if /^\s*#/ or /^\s*$/;
        my @F = split /\t/;
        my $geneid = $F[0];
        my $topology = simplify_topology($F[-1]);
        print $out_fh $excel ? "$geneid\t=\"$topology\"\n" : "$geneid\t$topology\n";
    }
    close_fh($in_fh, $out_fh);
}

