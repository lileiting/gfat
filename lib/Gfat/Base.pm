package Gfat::Base;
use warnings;
use strict;
use FindBin;
use Getopt::Long;
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(get_in_fh get_out_fh);

=head2 get_in_fh

  Title   : get_in_fh

  Usage   : my $fh = get_in_fh($infile);

  Function: Open a file and return the filehandle reference,
            if nothing was given, return the reference of 
            STDIN

  Args    : A file name or nothing

  Returns : A filehandle reference

=cut

sub get_in_fh{
    my $file = shift;
    my $fh;
    if($file){
        open $fh, "<", $file or die "$file:$!";
    }else{
        $fh = \*STDIN;
    }
    return $fh;
}

=head2 get_out_fh

  Title   : get_out_fh

  Usage   : my $fh = get_out_fh($outfile);

  Function: Open a file and return the filehandle reference,
            if nothing was given, return the reference of 
            STDOUT

  Args    : A file name or nothing

  Returns : A filehandle reference

=cut

sub get_out_fh{
    my $file = shift;
    my $fh;
    if($file){
        open $fh, ">", $file or die "$file:$!";
    }else{
        $fh = \*STDOUT;
    }
    return $fh;
}
