#!/usr/bin/env perl

use warnings;
use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use GFAT::ActionNew;
use Bio::AlignIO;
use Text::Abbrev;

sub get_aln_format{
    my $format = shift;
    return 'fasta' unless $format;
    my @formats = qw/bl2seq clustalw emboss fasta maf
        mase mega meme msf nexus pfam phylip prodom psi
        selex stockholm/;
    my %formats = abbrev @formats;
    if($formats{$format}){
        $format = $formats{$format};
    }else{
        warn <<"end_of_format";

ERROR: Unsupported alignment file format: $format!
Supported formats include:

    bl2seq      Bl2seq Blast output
    clustalw    clustalw (.aln) format
    emboss      EMBOSS water and needle format
    fasta       FASTA format
    maf         Multiple Alignment Format
    mase        mase (seaview) format
    mega        MEGA format
    meme        MEME format
    msf         msf (GCG) format
    nexus       Swofford et al NEXUS format
    pfam        Pfam sequence alignment format
    phylip      Felsenstein PHYLIP format
    prodom      prodom (protein domain) format
    psi         PSI-BLAST format
    selex       selex (hmmer) format
    stockholm   stockholm format

end_of_format
        exit;
    }
    return $format;
}

############################################################
sub rgaps{
    my $args = new_action(
        -desc => 'Remove gaps in alignment file',
        -options => {
            "format|f=s" => 'alignment format: bl2seq, clustalw, emboss,
                             fasta, maf, mase, mega, meme, msf, nexus, pfam,
                             phylip, prodom, psi, selex, stockholm
                             [default: fasta]'
        }
    );
    my $format = get_aln_format($args->{options}->{format});

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

sub stats{
    my $args = new_action(
        -desc => 'Print statistics of alignments',
        -options => {
            "format|f=s" => 'alignment format: bl2seq, clustalw, emboss,
                            fasta, maf, mase, mega, meme, msf, nexus, pfam,
                            phylip, prodom, psi, selex, stockholm
                            [default: fasta]',
            "title|t"    => 'Print title [default: no]'
        }
    );
    my $format = get_aln_format($args->{options}->{format});
    my $title = $args->{options}->{title};
    my $n;

    print join("\t", "#",          "File",       "Num_seq",    "SeqID1",     "SeqID2",
                     "#_Ident",    "#_Mismatch", "#_Gap\t",    "#_Gap_open",
                     "I+M+G",      "I/(I+M+G)%", "M/(I+M+G)%", "G/(I+M+G)%",
                     "I+M",        "I/(I+M)%",   "M/(I+M)%"
               )."\n" if $title;

    for my $i (0..$#{$args->{in_fhs}}){
        my $file = $args->{infiles}->[$i];
        my $fh = $args->{in_fhs}->[$i];

        my $alignio = Bio::AlignIO->new(-format => $format,
                                        -fh => $fh);
        while(my $aln = $alignio->next_aln){
            $n++;
            my @seqs = $aln->each_seq;

            my $seqid1 = $seqs[0]->display_id;
            my $seqid2 = $seqs[1]->display_id;

            my $len = $aln->length;
            my $num_seq = $aln->num_sequences;

            # Start count identical, mismatch, and gap columns
            my @countHashes;
            my @alphabet = ('A'..'Z','-','.');

            for( my $index=0; $index < $len; $index++) {
                       foreach my $letter (@alphabet) {
                           $countHashes[$index]->{$letter} = 0;
                       }
               }

            foreach my $seq (@seqs){
                my @seqChars = split //, $seq->seq();
                for( my $column=0; $column < @seqChars; $column++ ) {
                   my $char = uc($seqChars[$column]);
                   if (exists $countHashes[$column]->{$char}) {
                          $countHashes[$column]->{$char}++;
                   }else{ die "Undefined DNA/Protein/Gap character: $char!\n"; }
                }
            }

            my ($col_ident, $col_gap, $col_mismatch,$gap_open) = (0,0,0,0);
            my @gap_state;
            for(my $column =0; $column < $len; $column++) {
                my %hash = %{$countHashes[$column]};
                #print "Col $column:", (map{" $_/$hash{$_}"}(keys %hash)), "\n";
                $gap_state[$column] = 0;
                if($hash{'-'} or $hash{'.'}){
                    $col_gap++;
                    $gap_state[$column] = 1;
                    if($column == 0 or $gap_state[$column - 1] == 0){
                         $gap_open++
                    }
                }elsif((grep{$_ > 0}(values %hash)) == 1){
                    $col_ident++;
                }else{
                    $col_mismatch++;
                }
            }

            # Title:
            # #          File       Num_seq    SeqID1     SeqID2
            # #_Ident    #_Mismatch #_Gap      #_Gap_open
            # I+M+G      I/(I+M+G)% M/(I+M+G)% G/(I+M+G)%
            # I+M        I/(I+M)%   M/(I+M)%
            printf     join("\t", "%d",   "%s",   "%d",   "%s", "%s",
                           "%d",   "%d",   "%d",   "%d",
                           "%d",   "%.2f", "%.2f", "%.2f",
                           "%d",   "%.2f", "%.2f"
                    )."\n",
            $n,
            $file,
            $num_seq,
            $seqid1,
            $seqid2,

            $col_ident,
            $col_mismatch,
            $col_gap,
            $gap_open,

            $col_ident + $col_mismatch + $col_gap,
            $col_ident / ($col_ident + $col_mismatch + $col_gap) * 100,
            $col_mismatch / ($col_ident + $col_mismatch + $col_gap) * 100,
            $col_gap / ($col_ident + $col_mismatch + $col_gap) * 100,

            $col_ident + $col_mismatch,
            ($col_ident + $col_mismatch) ? $col_ident / ($col_ident + $col_mismatch) * 100 : 0,
            ($col_ident + $col_mismatch) ? $col_mismatch / ($col_ident + $col_mismatch) * 100 : 0

        }
    }
}

sub main{
    my %actions = (
        rgaps    => 'Remove gaps in alignment',
        stats    => 'Print statistics of alignments',
    );
    script_usage(%actions) unless @ARGV;
    &{\&{&get_action_name}};
}

main() unless caller;

__END__
