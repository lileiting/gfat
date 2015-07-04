package Gfat::FormatSeqStr;
use warnings;
use strict;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(format_seqstr);

sub format_seqstr{
    my $str = shift;
    my $len = length($str);
    $str =~ s/(.{60})/$1\n/g;
    chomp $str;
    return $str;
}

1;
