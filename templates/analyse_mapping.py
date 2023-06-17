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

import pysam
import pandas as pd

# Open input SAM file for reading.
samfile = pysam.AlignmentFile('${samFiltFile}', 'r')

# Using Pysam library obtain data existing in the input SAM file as well as
# mapped read end postion and strand. Correct mapping start and end postion
# to be compliant with raw SAM format and GenBank notation, i.e. 1-based and
# both indices inclusive.
data = [
    [
        # Data existing in SAM files:
        alignment.query_name,                                 # QNAME
        alignment.flag,                                       # FLAG
        samfile.get_reference_name(alignment.reference_id),   # RNAME
        alignment.reference_start + 1,                        # POS
        alignment.mapping_quality,                            # MAPQ
        alignment.cigarstring,                                # CIGAR
        # New data calculated based on CIGAR and FLAG:
        alignment.reference_end,                              # end
        'minus' if alignment.is_reverse else 'plus'           # strand
    ]
    for alignment in samfile
]

samfile.close()

# Convert data[] list into a Pandas DataFrame, use SAM column names in lower case.
names = 'qname flag rname pos mapq cigar end strand'.split()
df = pd.DataFrame(data, columns=names)

# Save the resulting DataFrame with the two new columns (end and strand) to
# a TSV file. Use GZIP compression.
df.to_csv('${mappingTsvFile}', index=None, compression='gzip', sep='\\t')

