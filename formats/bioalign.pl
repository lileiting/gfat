#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use Bio::AlignIO;

sub main_usage{
    print <<"end_of_usage";

USAGE
    $FindBin::Script Action [Options]

AVAILABLE ACTIONS
    rgaps    | remove gaps in alignment

end_of_usage
    exit;
}

sub main{
    main_usage unless @ARGV;
    my $args = shift @ARGV;
    if(defined &{\&{$args}}){
        &{\&{$args}};
    }
    else{
        die "CAUTION: action $args was not defined!\n";
    }
}

main() unless caller;

############################################################
# Defination of Actions                                    #
############################################################

sub rgaps{
    my $args = new_action(
        -desc => 'Remove gaps in alignment file',
        -options => {
		   "format|f=s" => 'alignment format: bl2seq, clustalw, emboss, 
		                    fasta, maf, mase, mega, meme, msf, nexus, pfam,
		                    phylip, prodom, psi, selex, stockholm'
        }
    );
    my $format = $args->{options}->{format};
    
    for my $fh (@{$args->{in_fhs}}){
        my $aln_in = Bio::AlignIO->new(-format => $format, 
                                        -fh => $fh);
        my $aln = $aln_in->next_aln;
	    $aln_in->close;
	    my $aln_out = Bio::AlignIO->new(-format=>'fasta', 
                                    -fh=> \*STDOUT);
	    $aln_out->write_aln($aln->remove_gaps('-',1));
	    $aln_out->close;
    }

}

__END__
