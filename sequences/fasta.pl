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
  sort   | Sort sequences by name
  rmdesc | Remove sequence descriptions

USAGE
    exit;
}

sub read_commands{
    usage unless @ARGV;
    my @cmd = qw/idlist length sort rmdesc/;
    my %cmd = map{$_ => 1}@cmd;
    my $cmd = shift @ARGV;
    warn "Unrecognized command: $cmd!\n" and usage unless $cmd{$cmd};
    return $cmd;
}

sub main{
    my $cmd = read_commands;
    fasta_cmd($cmd);
}

main;
