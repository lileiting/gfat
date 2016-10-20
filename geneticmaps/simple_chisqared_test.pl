#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use GFAT::Chisquare;
our $in_desc = 'in.map';

sub main{
    my %actions = (
        f1test => 'Test nnxnp, lmxll, or hkxhk codes'
    );
    &{ \&{run_action( %actions )} };
}

sub f1test{
    my $args = new_action(
        -desc => 'Test nnxnp, lmxll, or hkxhk codes',
        -options => {
            "pvalue|p=f" => 'P value cutoff [default: 0.05]'
        }
    );

    my $pvalue = $args->{options}->{pvalue} // 0.05;

    for my $fh (@{$args->{in_fhs}}){
        while(<$fh>){
            chomp;
            my @f = split /\t/;
            my $marker = $f[0];
            my @codes = @f[1..$#f];
            my %codes;
            map{$codes{$_}++}@codes;
            my $seg_type;
            my @observed;
            if(exists $codes{np} or exists $codes{nn}){
                $seg_type = 'nnxnp';
                @observed = map{$codes{$_} // 0}qw(nn np);
            }
            elsif(exists $codes{lm} or exists $codes{ll}){
                $seg_type = 'lmxll';
                @observed = map{$codes{$_} // 0}qw(lm ll);
            }
            elsif(exists $codes{hh} or exists $codes{hk} or exists $codes{kk}){
                $seg_type = 'hhxhk';
                @observed = map{$codes{$_} // 0}qw(hh hk kk);
            }
            elsif(exists $codes{h} or exists $codes{a} or exists $codes{b}){
                $seg_type = '1:2:1';
                @observed = map{$codes{$_} // 0}qw(a h b);
            }
            else{
                warn "WARNING! Unrecognized codes for $marker\n";
                next;
            }

            my $p = chisqtest($seg_type, @observed);

            if($p < $pvalue){
                #warn "$.: Marker $marker, P value: $p\t".
            #        join(",", map{$_.":".$codes{$_}}
            #            sort {$a cmp $b} keys %codes)."\n";
                next;
            }
            print join ("\t", @f)."\n";
        }
    }
}

main unless caller;

__END__
