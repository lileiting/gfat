#!/usr/bin/env perl

use warnings;
use strict;
use Bio::Perl;
use File::Basename;
use Getopt::Long;

sub usage{
	die "Usage: ",basename($0), 
" [-h|?] [-d DB] [-f FORMAT] [-a ACC[,ACC ...]] [LISTFILE [LISTFILE ...]]
Supported databases (Default: genbank):
    genbank
    genpept
    swiss
    embl
    refseq

Default format:fasta
Other formats please refer to 
http://www.bioperl.org/wiki/HOWTO:SeqIO#Formats
	\n";
}
&usage unless @ARGV;

my $help = 0;
my $db = 'genbank';
my $format = 'fasta';
my @acc = ();
my @files;

GetOptions("help|?"     =>  \$help,
           "db=s"       =>  \$db,
           "format=s"   =>  \$format,
           "acc=s"      =>  \@acc);

&usage if($help);
&usage unless($db =~ /genbank|genpept|swiss|embl|refseq/i);
@acc = split(/,/,join(",", @acc));
@files = @ARGV;
&usage unless(@acc or @files);

my @seqs;
if(@acc){
	for(@acc){
		warn "Fetching $_ ...\n";
		push @seqs, get_sequence($db, $_);
	}
}
if(@files){
	for my $file (@files){
		open my $fh, $file or die "ERROR in opening file $file ...\n";
		while(<$fh>){
			next if /^\s*$/ or /^\s*#/;
			s/[\r\n]//g;
			warn "Fetching $_ ...\n";
			push @seqs, get_sequence($db, $_);
		}
		close $fh;
	}
}

write_sequence(">-", $format, @seqs);
