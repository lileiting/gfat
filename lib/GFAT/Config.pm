package GFAT::Config;
use warnings;
use strict;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(print_version);
@EXPORT_OK = qw($VERSION $textwidth $seqwidth print_version);

our $VERSION = '0.1.250';
our $textwidth = 70;
our $seqwidth = 60;

sub print_version{
    print "$VERSION\n";
    exit;
}

1;
