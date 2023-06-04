#!/usr/bin/env Rscript

# Created by Michal Bukowski (michal.bukowski@tuta.io) under GPL-3.0 license.
# The file is a template file for hg-mapping Nextflow workflow. It cannot be
# run as an independent script.

# The script obtaines expression matrices from TCGA (The Cancer Genome Atlas Program)
# for gene ids found in the gene_ids column in an input TSV file.
# Input:
# -- genesTsvFile   - a gzipped TSV file that contains gene ids in gene_ids column.
# -- samplesTxtFile - a text file that contains TCGA sample ids (one per line)
#                     the matrices are expected to be fetched for.
# Output:
# -- matrixTsvFile  - a gzipped TSV file that the first (index) column contains
#                     gene ids and the remaining ones expression data for the samples
#                     in the order their ids were provided in the input file.

library("stringi")
library("data.table")
library("TCGAbiolinks")
library("SummarizedExperiment")

# Read TGCA sample ids from an input text file (one id per line).
sampleIds <- fread(
    "${samplesTxtFile}",
    header = FALSE,
    blank.lines.skip = TRUE,
    col.names = c("sample")
)\$sample

# Read the data on genes from an input TSV file that contains gene_ids columns,
# which may contain multiple gene ids separated by a semicolon followed by a space
# ("; "). Split such values in respect to the separator and flatten the results
# to a list of gene ids.
geneData <- fread("${genesTsvFile}", header=TRUE, select="gene_ids", sep="\\t")
geneIds  <- unlist( strsplit(geneData\$gene_ids, "; ") )

# Fetch expression data for sampleIds from TCGA-BRCA project.
query <- GDCquery(
    project       = "TCGA-BRCA", 
    data.category = "Transcriptome Profiling",
    data.type     = "Gene Expression Quantification",
    barcode       = sampleIds
)
GDCdownload(query)

# Prepare the expression matrix.
BRCA.Rnaseq.SE <- GDCprepare(query)
BRCAMatrix     <- assay(BRCA.Rnaseq.SE, "unstranded")

# Strip version suffixes from rownames (gene ids).
rownames(BRCAMatrix) <- stri_extract_first(rownames(BRCAMatrix), regex="[^.]+")
# Check which desired gene ids are not present in the matrix and defined
# those to be selected as geneIds - missing.
missing  <- setdiff(geneIds, rownames(BRCAMatrix))
selected <- setdiff(geneIds, missing)

# Select rows for desired and present in the matrix genes.
BRCAMatrix_subset <- BRCAMatrix[selected,]

# Save the resulting expression matrix to TSV file. Use GIZP compression.
write.table(
    BRCAMatrix_subset,
    file = gzfile("${matrixTsvFile}"),
    col.names = NA,
    quote = FALSE,
    sep = "\\t"
)
