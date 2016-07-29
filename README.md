[![DOI](https://zenodo.org/badge/doi/10.5281/zenodo.58774.svg)](http://dx.doi.org/10.5281/zenodo.58774)

# Gene Families and genetic maps Analyses Tools

* Author: [Leiting Li](https://github.com/lileiting)
* Email: lileiting@gmail.com
* Licence: [BSD](http://opensource.org/licenses/BSD-2-Clause)

This is a collection of tools for gene family, genetic maps and comparative 
genomics analyses.

## Intallation
    git clone https://github.com/lileiting/gfat.git

## How to use

Shortcuts were supported for some of these scripts. For instance,

    gfat.pl f f g

is equivalent to

    gfat.pl formats fasta getseq

### FASTA sequences

Print the ID for a FASTA sequence file in.fasta

    gfat.pl formats fasta idlist in.fasta
    cat in.fasta | gfat.pl formats fasta idlist
    gfat.pl formats fasta idlist -i in.fasta
    gfat.pl formats fasta idlist --input in.fasta

    # With description
    gfat.pl formats fasta idlist in.fasta -d
    # Write results to a file
    gfat.pl formats fasta idlist in.fasta -o idlist.txt

Print sequence length

    gfat.pl formats fasta length in.fasta

Fetch sequences match a pattern

    # Find WRKY genes
    gfat.pl formats fasta motif in.fasta -p 'WRKYG[QK]K'
    # Find sequences contain SSRs
    gfat.pl formats fasta motif in.fasta -p '(([ATGC]{2,6}?)\2{3,})'

Get sequences based on sequence name

    gfat.pl formats fasta getseq in.fasta -s gene1
    gfat.pl formats fasta getseq in.fasta -s gene1 -s gene2
    gfat.pl formats fasta getseq in.fasta -s gene1,gene2
    gfat.pl formats fasta getseq in.fasta -p 'gene\d'
    gfat.pl formats fasta getseq in.fasta -l list.txt
    gfat.pl formats fasta getseq in.fasta -s gene1 -s gene2 -s gene3,gene4 -p 'name\d' -l list.txt

## Acknowledgements

The scripts, functions and usage styles are largely inspired 
by Haibao Tang's [JCVI](https://github.com/tanghaibao/jcvi)
utility libraries (Python based). 

The scripts were also inspired by the 
[p5-bpwrapper](https://github.com/bioperl/p5-bpwrapper) 
and other Perl based modules or scripts.

## Citation

Leiting Li. (2016). gfat: Gene Families and genetic maps Analyses Tools v0.1. Zenodo. [10.5281/zenodo.58774](https://dx.doi.org/10.5281/zenodo.58774).
