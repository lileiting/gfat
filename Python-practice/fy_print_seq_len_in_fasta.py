#!/usr/bin/env python

'''
Script: fy_print_seq_len_in_fasta.py
Function: Print sequence length to STDOUT in fasta file
Note: Python3 is not default installed for most computer, 
      and the extra-installed module like Biopython could
      not be directly used by python3. So, it's not the
      righ time to use Python3 now.
Date: 2014/11/11
'''

import sys
if len(sys.argv) < 2:
    print('Usage: ' + sys.argv[0] + ' <FASTA>')
    sys.exit()

from Bio import SeqIO
seqlen     = []
num_of_seq = 0
total_len  = 0
for record in SeqIO.parse(sys.argv[1], 'fasta'):
    print("%s %i" % (record.id, len(record)))
    num_of_seq += 1
    total_len += len(record)
    seqlen.append(len(record))

seqlen.sort()
min_len = seqlen[0]
max_len = seqlen[-1]

print("Number of sequences: " + str(num_of_seq))
print("Total length: " + str(total_len))
print("Max length: " + str(max_len))
print("Min length: " + str(min_len))
