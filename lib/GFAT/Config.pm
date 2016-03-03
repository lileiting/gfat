package GFAT::Config;
use warnings;
use strict;
use File::Basename;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = qw(print_version get_cmd);
@EXPORT_OK = qw($VERSION $textwidth $seqwidth print_version);

our $VERSION = '0.3.1';
our $textwidth = 70;
our $seqwidth = 60;

sub print_version{
    print "$VERSION\n";
    exit;
}

sub get_cmd{
    my $category = basename $FindBin::RealBin;
    my $script = $FindBin::Script;
    $script =~ s/\.pl//;
    return "gfat.pl $category $script";
}

1;
