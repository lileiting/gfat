#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use Bio::Perl;

sub genbank{
    my $args = new_action(
        -desc => 'Fetch sequences from genbank, eg. NM_022163.3, GI:169658372'
    );
    my $out = Bio::SeqIO->new(-fh => $args->{out_fh}, -format=>'fasta');
    my @terms = @{$args->{infiles}};
    for my $term (@terms){
        my $seq = get_sequence('genbank',$term);
        $out->write_seq($seq);
    }

}

sub main{
    my %actions = (
        genbank => 'Fetch sequences from genbank',
    );
    script_usage(%actions) unless @ARGV;
    &{\&{&get_action_name}};
}

main unless caller;

__END__
