#!/usr/bin/env python3

# Created by Michal Bukowski (michal.bukowski@tuta.io) under GPL-3.0 license.
# The file is a template file for hg-mapping Nextflow workflow. It cannot be
# run as an independent script.

# The script analyses an input SAM file in order to provide end locations and
# the strand for read mappings.
# Input:
# -- samFiltFile    - a gzipped SAM file with filtered mapping data
# Output:
# -- mappingTsvFile - a gzipped TSV file that next to QNAME, FLAG, RNAME, POS,
#                     MAPQ, CIGAR columns from the input SAM file (names are
#                     converted to lower case), provides two extra columns:
#                     end (the end location of a read mapping) and strand
#                     (the strand a read is mapped to).

import gzip
import pandas as pd

# SAM file column names and their positions.
QNAME = 0
FLAG  = 1
RNAME = 2
POS   = 3
MAPQ  = 4
CIGAR = 5

# CIGAR codes that consume the reference sequences (REF) and remaining ones.
CIGAR_REF   = 'MDN=X'
CIGAR_OTHER = 'ISHP'

def ref_span(cigar: str) -> int:
    '''For a given CIGAR string compute how many positions of the reference sequence
       is consumed by an alignment. For more information see:
       https://en.wikipedia.org/wiki/Sequence_alignment#CIGAR_Format
    '''
    # ref_span - the total number of positions an alignment consumes from the reference
    ref_span = 0
    # start position of a currently parsed CIGAR event
    start = 0
    # Iterate over CIGAR positons and parse subsequent events.
    for pos, letter in enumerate(cigar):
        if letter in CIGAR_OTHER:
            start = pos + 1
        elif letter in CIGAR_REF:
            ref_span += int(cigar[start:pos])
    # Return the total number of positions an alignment consumes from the reference
    return ref_span

# Collect values of QNAME, FLAG, RNAME, POS, MAPQ, CIGAR columns form subsequent
# rows of an input SAM file to data[] list.
data = []
f = gzip.open('${samFiltFile}', 'rt')
for line in f:
    if line[0] == '@':
        continue
    fields = line.rstrip().split('\\t', 10)
    data.append( [ fields[i] for i in [QNAME, FLAG, RNAME, POS, MAPQ, CIGAR] ] )

# Convert data[] list into a Pandas DataFrame, use SAM column names in lower case.
df = pd.DataFrame(data, columns='qname flag rname pos mapq cigar'.split())

# Convert the pos column into integer type.
df['pos'] = df['pos'].astype(int)
# Calculate end positons of mapped reads using SAM pos column and span values
# returned by the previously defined ref_span() function.
df['end'] = df['pos'] + df['cigar'].apply(ref_span) - 1
# Based on flag values determine the strand reads are mapped to.
df['strand'] = 'plus'
df['flag'] = df['flag'].astype(int)
df.loc[df['flag'] & 0b10000 == 16, 'strand'] = 'minus'

# Save the resulting DataFrame with the two new columns (end and strand) to
# a TSV file. Use GZIP compression.
df.to_csv('${mappingTsvFile}', index=None, compression='gzip', sep='\\t')

