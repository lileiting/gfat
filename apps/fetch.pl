#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use Bio::Perl;
use Text::Abbrev;
our $in_desc = '<term> [<term> ...]';

sub main{
    my %actions = (
        getsequence => 'Fetch sequences from genbank',
    );
    &{\&{run_action(%actions)}};
}

main unless caller;


sub getsequence{
    my $args = new_action(
        -desc => 'Fetch sequences from remote databases like genbank by
            provided accession numbers, e.g. NM_022163.3, GI:169658372',
        -options => {
            "database|d=s" => "Database: Swissprot ('swiss'), EMBL ('embl'),
                GenBank('genbank'), GenPept ('genpept'), and RefSeq ('refseq')
                [default: genbank]",
            "format|f=s" => 'Output sequence formats: ace, asciitree, chaosxml,
                embl, fasta, gcg, genbank, pir, raw, swiss,tab [default: fasta]
                See: http://bioperl.org/howtos/SeqIO_HOWTO.html',
            "listfile|l=s" => 'A list file providing accession numbers one per
                line, or in first column of a tab file'
        }
    );
    my $database = $args->{options}->{database} // 'genbank';
    my $format = $args->{options}->{format} // 'fasta';
    my $listfile = $args->{options}->{listfile};
    my $out = Bio::SeqIO->new(-fh => $args->{out_fh}, -format => $format);
    my @terms = @{$args->{infiles}};
    if($listfile){
        open my $list_fh, $listfile or die "$!: $listfile\n";
        while(<$list_fh>){
            next if /^\s*$/ or /^\s*#/;
            chomp;
            push @terms, (split /\t/)[0];
        }
        close $list_fh;
    }
    for my $term (@terms){
        my $seq = get_sequence('genbank',$term);
        $out->write_seq($seq);
    }

}

__END__
