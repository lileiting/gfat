package GFAT::Base;
use warnings;
use strict;
use FindBin;
use Getopt::Long;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(GetInFh GetOutFh);

=head2 GetInFh

  Title   : GetInFh

  Usage   : my $fh = GetInFh($infile);

  Function: Open a file and return the filehandle reference,
            if nothing was given, return the reference of 
            STDIN

  Args    : A file name or nothing

  Returns : A filehandle reference

=cut

sub GetInFh{
    my $file = shift;
    my $fh;
    if($file and $file ne '-'){
        open $fh, "<", $file or die "$file:$!";
    }else{
        $fh = \*STDIN;
    }
    return $fh;
}

=head2 GetOutFh

  Title   : GetOutFh

  Usage   : my $fh = GetOutFh($outfile);

  Function: Open a file and return the filehandle reference,
            if nothing was given, return the reference of 
            STDOUT

  Args    : A file name or nothing

  Returns : A filehandle reference

=cut

sub GetOutFh{
    my $file = shift;
    my $fh;
    if($file and $file ne '-'){
        open $fh, ">", $file or die "$file:$!";
    }else{
        $fh = \*STDOUT;
    }
    return $fh;
}

1;
