#!/usr/bin/env perl

use warnings;
use strict;
use File::Basename;
use Bio::AlignIO;

sub usage{
  die "Usage: ", basename($0), " {format} <ALIGNMENT> [<ALIGNMENT> ...]
       format
           Specify the format of the file.  Supported formats include:

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

Note that abbreviations of formats are supported, so typing the first 
letter or first few letters of a format are sufficient\n"
}

&usage unless @ARGV;

my $format = shift @ARGV;
$format = do {
	$_ = $format;
	if(   /^b/){	'bl2seq'}
	elsif(/^c/){	'clustalw'}
	elsif(/^e/){	'emboss'}
	elsif(/^f/){	'fasta'}
	elsif(/^maf/){	'maf'}
	elsif(/^mas/){	'mase'}
	elsif(/^meg/){	'mega'}
	elsif(/^mem/){	'meme'}
	elsif(/^ms/){	'msf'}
	elsif(/^n/){	'nexus'}
	elsif(/^pf/){	'pfam'}
	elsif(/^ph/){	'phylip'}
	elsif(/^pr/){	'prodom'}
	elsif(/^ps/){	'psi'}
	elsif(/^se/){	'selex'}
	elsif(/^st/){	'stockholm'}
	else{
		print "ERROR: Unsurpported alignment file format: $_!\n";
		&usage;
	}
};

my $c;

print join("\t", "#",          "File",       "Num_seq",    "SeqID1",     "SeqID2", 
                 "#_Ident",    "#_Mismatch", "#_Gap\t",    "#_Gap_open", "I+M+G", 
                 "I/(I+M+G)%", "M/(I+M+G)%", "G/(I+M+G)%", "I+M",        "I/(I+M)%", 
                 "M/(I+M)%"), \n";

for my $file (@ARGV){
	my $alignio = Bio::AlignIO->new(-format => $format,
        	                        -file => $file);

	while(my $aln = $alignio->next_aln){
		$c++;

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
           			}else{
					die "Undefined DNA/Protein/Gap character: $char!\n";
				}
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
		printf 	join("\t", "%d",   "%s",   "%d",   "%s", "%s", 
		                   "%d",   "%d",   "%d",   "%d", 
		                   "%d",   "%.2f", "%.2f", "%.2f", 
		                   "%d",   "%.2f", "%.2f"              
		            )."\n",
			$c,
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
			$col_ident / ($col_ident + $col_mismatch) * 100,
			$col_mismatch / ($col_ident + $col_mismatch) * 100
	}
}
