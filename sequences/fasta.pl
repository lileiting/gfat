#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use fasta;

sub usage{
    print <<USAGE;

$FindBin::Script CMD [OPTIONS]

CMD:
  idlist | Get ID list of a sequence file
  length | Print sequence length
  sort   | Sort sequences by name/sizes
  rmdesc | Remove sequence descriptions
  getseq | Get sequences by ID pattern

USAGE
    exit;
}

sub main{
    usage unless @ARGV;
    my $cmd = shift @ARGV;
    fasta_cmd($cmd);
}

main() unless caller;
