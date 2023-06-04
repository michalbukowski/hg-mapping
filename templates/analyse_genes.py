#!/usr/bin/env python3

# Created by Michal Bukowski (michal.bukowski@tuta.io) under GPL-3.0 license.
# The file is a template file for hg-mapping Nextflow workflow. It cannot be
# run as an independent script.

# The script analyses locations of reads within reference sequences and fetches
# names and ids of genes found in those locations based on reference sequence
# annotations.
# Input:
# -- mappingTsvFile - a gzipped SAM file with filtered mapping data
# -- genomeGtfFile  - a gzipped GTF file with annotations for the reference sequences
# Output:
# -- genesTsvFile   - a gzipped TSV file with qname (read ids), genes_names,
#                     gene_ids columns that contain names and ids of genes
#                     in locations where reads are mapped

import pandas as pd
from pyensembl import Genome

def get_gene_info(row: pd.Series, col_names: list, genome: Genome) -> pd.Series:
    '''For a Pandas DataSeries row that contains reference sequence name (rname),
       a read start and end position (pos, end), as well as based on
       an annotation GFT file, fetches gene names and ids that are annotated in
       the location where the read is mapped. If more than one gene is found
       in the location, names and ids are separated by a semicolon followed by
       a space ('; '). Such string values are returned as a Pandas Series,
       the index of which is ['gene_names', 'gene_ids'].
    '''
    # Fetch a list of PyEnsembl Gene object describing genes found in the location
    # where a read is mapped.
    genes = genome.genes_at_locus(
        contig=row['rname'], position=row['pos'], end=row['end']
    )
    # create two strings, one for gene names, the other for gene ids
    gene_names = '; '.join(
        gene.gene_name for gene in genes if gene.gene_name != ''
    )
    gene_ids   = '; '.join( gene.gene_id   for gene in genes )
    # Return the resuting strings wrapped up in Pandas Series object.
    series = pd.Series(
        [gene_names, gene_ids],
        index='gene_names gene_ids'.split()
    )
    return series

# Create a PyEnsembl Genome object based on the input GTF annotaion file and then
# build an index for annotations.
genome = Genome(
    reference_name = 'genome',
    annotation_name = 'genome_annots',
    gtf_path_or_url = '${genomeGtfFile}',
)
genome.index()

# Read to a Pandas DataFrame a TSV file with mapping analysis that among all
# contains locations of mapped reads within the reference sequences.
df = pd.read_csv(
    '${mappingTsvFile}', index_col=None, compression='gzip', sep='\\t'
)

# Utilise previously defined get_gene_info() function by applying it to
# the DataFrame in order to create two new columns (gene_names and gene_ids)
# containg names and ids for genes found in the locations of mapped reads.
col_names = 'gene_names gene_ids'.split()
df[col_names] = df.apply(get_gene_info, args=(col_names, genome), axis=1)

# Select the qname (read ids) together with the two new columns and save
# the resulting DataFrame to the output file. Use GZIP compression.
df[ ['qname'] + col_names].to_csv(
    '${genesTsvFile}', index=None, compression='gzip', sep='\\t'
)

