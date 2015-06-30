#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Formats::Fasta qw(fasta_cmd);

sub usage{
    print <<USAGE;

$FindBin::Script CMD [OPTIONS]

CMD:
     idlist | Get ID list of a sequence file
     length | Print sequence length
       sort | Sort sequences by name/sizes
     rmdesc | Remove sequence descriptions
     getseq | Get sequences by ID pattern
  translate | Translate CDS to protein sequence
         gc | GC content
      clean | Clean irregular chars

USAGE
    exit;
}

sub main{
    usage unless @ARGV;
    my $cmd = shift @ARGV;
    usage if $cmd eq q/-h/ or $cmd eq q/--help/;
    fasta_cmd($cmd);
}

main() unless caller;
