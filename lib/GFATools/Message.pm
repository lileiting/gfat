package GFAT::Message;
use warnings;
use strict;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(msg w p hr seg);

sub msg{local $\ = "\n"; print STDERR @_}
sub w  {local $\ = "\n"; print STDERR @_}
sub p  {local $\ = "\n"; print STDOUT @_}
sub print_line { # Horizontal line
    my $sign = shift;
    if(@_){
        for(@_){
            my $len = length($_);
            my $n1 = $len >= 58 ? 2 : (60 - $len) / 2;
            my $n2 = $len >= 58 ? 2 : sprintf("%.0f", (60 - $len) / 2);
            w $sign x $n1 . $_ . $sign x $n2;
        }
    }else{
        w $sign x 60;
    }
}
sub hr {print_line qq/-/, @_}
sub seg {print_line qq/=/, @_}

1;
