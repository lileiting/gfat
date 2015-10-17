package GFAT::LoadFile;

use warnings;
use strict;
use parent qw(Exporter);
use vars qw(@EXPORT @EXPORT_OK);
@EXPORT = qw(load_listfile);
@EXPORT_OK = @EXPORT;

sub load_listfile{
    my @files = @_;
    my %listid;
    for my $file (@files){
        open my $fh, "<", $file or die "$file: $!";
        while(<$fh>){
            next if /^\s*#/ or /^\s*$/;
            s/^\s+//g;
            die "ERROR in list file: $_!!!" unless /^(\S+)/;
            $listid{$1}++;
        }
        close $fh;
    }
    return \%listid;
}

1;
