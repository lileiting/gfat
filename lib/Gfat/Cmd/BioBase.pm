=head1 NAME

Gfat::Cmd::BioBase - Base modules that used for build commands

=head1 SYNOPSIS

  use Gfat::Cmd::Base qw(get_seqio, close_seqio);

  # For simple options with only input, output and help
  my $cmd = shift @ARGV // die;
  my ($in_seqio, $out_seqio) = get_fh($cmd);
  my ($in_seqio, $out_seqio, $options) = get_fh($cmd);
  ...
  close_seqio($in_seqio, $out_seqio);

=head1 DESCRIPTION

Subroutines that assist defining commands for read and write FASTA files

=head1 FEEDBACK

Create an issue in GitHub <https://github.com/lileiting/gfatk/issues>

=head1 AUTHOR

Leiting Li, Email: lileiting@gmail.com

=head1 APPENDIX

The rest of the documentation details each of the subroutine.

=cut

package Gfat::Cmd::BioBase;
use warnings;
use strict;
use Bio::SeqIO;
use Gfat::Cmd::Base qw(get_fh);
use vars qw(@EXPORT @EXPORT_OK);
use base qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(get_seqio close_seqio);

=head2 get_seqio

  Title   : get_seqio
  Usage   : my ($in_io, $out_io) = get_seqio($cmd);

  Function: An shortcuts for simply get the Bio::SeqIO filehandles, 
            assuming the file format is FASTA

  Returns : An array contains two elements, the input Bio::SeqIO 
            filehandle, and output Bio::SeqIO filehandle.

  Args    : A string, the command name

=cut

sub get_seqio{
    my($in_fh, $out_fh, $options) = get_fh(@_);
    my $in_io = Bio::SeqIO->new(-fh => $in_fh, -format=>'fasta');
    my $out_io = Bio::SeqIO->new(-fh => $out_fh, -format=>'fasta');
    return ($in_io, $out_io, $options);
}

=head2 close_seqio

  Title   : close_seqio
  Usage   : close_fh($in_io, $out_io);

  Function: Close Bio::SeqIO filehandles

  Returns : 1

  Args    : An array contains Bio::SeqIO filehandle(s)

=cut

sub close_seqio{
    my @seqio = @_;
    for my $io (@seqio){
        $io->close;
    }
    1;
}

1;
