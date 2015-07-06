# Gene family analysis tools

* Author: [Leiting Li](https://github.com/lileiting)
* Email: lileiting@gmail.com
* Licence: [BSD](http://opensource.org/licenses/BSD-2-Clause)

This is a collection of tools about gene family analysis or 
comparative genomics.

## Intallation
    git clone https://github.com/lileiting/gfat.git

## FASTA sequences

Print the ID for a FASTA sequence file in.fasta

    ./formats/fasta.pl idlist in.fasta
    cat in.fasta | ./formats/fasta.pl idlist
    ./formats/fasta.pl idlist -i in.fasta
    ./formats/fasta.pl idlist --input in.fasta

    # With description
    ./formats/fasta.pl idlist in.fasta -d
    # Write results to a file
    ./formats/fasta.pl idlist in.fasta -o idlist.txt

Print sequence length

    ./formats/fasta.pl length in.fasta

Fetch sequences match a pattern

    # Find WRKY genes
    ./formats/fasta.pl motif in.fasta -p WRKYGQK
    # Find sequences contain SSRs
    ./formats/fasta.pl motif in.fasta -p '(([ATGC]{2,6}?)\2{3,})'


