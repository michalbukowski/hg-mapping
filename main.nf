#!/usr/bin/env nextflow

/* Created by Michal Bukowski (michal.bukowski@tuta.io) under GPL-3.0 license.
   Nextflow file defining hg-mapping workflow. For more information see the
   README.md file.
   
   The workflow uses parameters defined in nextflow.config file. Please refer
   to the file and comments provided there before introducing any modification
   to this file.
*/

/* Builds reference sequecne index from sequences in the input genomeFastaFile.
   Saves index files to indexDir with the prefix 'index'. Emits a tuple of
   the index directory (indexDir) and the full index prefix (indexPrefix).
*/
process buildIndex{
    conda      params.condaEnvPy
    publishDir 'output', mode: 'link'
    shell      '/bin/bash', '-euo', 'pipefail'
    cpus       params.maxThreads
    
    input:
        path genomeFastaFile
    
    exec:
        indexDir    = 'index'
        indexPrefix = 'genome'
    
    output:
        tuple path(indexDir), val(indexPrefix)
    
    script:
    """
    mkdir -p index
    bowtie2-build --threads ${task.cpus}       \
                    ${genomeFastaFile}         \
                    ${indexDir}/${indexPrefix}
    """
}

/* Maps reads from the readsFile using the index build by the buildIndex process.

   Consumes the tuple emitted the buildIndex process combined with a path to the
   input readsFile that contains read sequences. Emits a path of gzipped SAM file
   (samFile) that contains the mapping results.
   
   For bowtie2 the minumum alignment score function and the length of seed substrings
   is adjusted to very short input reads (~20 nt). For the same reason the very
   sensitive local mode is selected. The local mode is also selected to allow
   trimming of read ends.
*/
process mapReads{
    conda      params.condaEnvPy
    publishDir 'output', mode: 'link'
    shell      '/bin/bash', '-euo', 'pipefail'
    cpus       params.maxThreads
    
    input:
        tuple path(indexDir), val(indexPrefix), path(readsFile)
    
    exec:
        samFile = 'mapping.sam.gz'
    
    output:
        path samFile
    
    script:
    """
    bowtie2 --threads ${task.cpus}         \
            --very-sensitive-local         \
            --score-min G,10,8             \
             -L 10                         \
             -f                            \
             -x ${indexDir}/${indexPrefix} \
             -U ${readsFile}               \
          | gzip -c                        \
          > ${samFile}
    """
}

/* Filters the mapping results of the mapReads process in respect to MAPQ >= 30.

   Consumes the path emitted by the process and emits a path of gzipped SAM file
   (samFiltFile) that contains the filtered mapping results.
*/
process filterMapping{
    conda      params.condaEnvPy
    publishDir 'output', mode: 'link'
    shell      '/bin/bash', '-euo', 'pipefail'
    cpus       params.maxThreads
    
    input:
        path samFile
    
    exec:
        samFiltFile = 'mapping_filtered.sam.gz'
    
    output:
        path samFiltFile
        
    script:
    """
    samtools view --threads ${task.cpus} \
                  --output-fmt sam       \
                   -h                    \
                   -q 30                 \
                   -o ${samFiltFile}   \
                      ${samFile}
    """
}

/* Analyses filtered mapping results generated by the filterMapping process.

   Consumes the path emitted by the filterMapping process and emits a path
   to a gzipped TSV file (mappingTsvFile).
   
   The output file, next to QNAME, FLAG, RNAME, POS, MAPQ, CIGAR columns
   from the SAM input file (names are converted to lower case), renders
   the end (based on CIGAR) and strand (based on FLAG) columns that denote
   the end location of a read within the reference sequence and the strand
   of the reference sequence a read was mapped to.
*/
process analyseMapping {
    conda      params.condaEnvPy
    publishDir 'output', mode: 'link'
    
    input:
        path samFiltFile
    
    exec:
        mappingTsvFile = 'mapping_analysis.tsv.gz'
    
    output:
        path mappingTsvFile
    
    script:
        template 'analyse_mapping.py'
}

/* Using PyEnsembl Python module obtains information of genes the reads were
   mapped within. Reference sequence names as well as start and end positions
   of reads are obtained from the file generated by the analyseMapping process.
   
   Consumes a tuple of the path (emitted by the analyseMapping process) combined
   with a path to the input genomeGtfFile that indicates the location of the file
   with annotations for the reference sequences. Emits a path to a gzipped TSV
   file (genesTsvFile).
   
   The output file contains qname column (a read sequence id) next to gene_names
   and gene_ids columns that contain gene names and ids obtained from
   Ensembl database. If there is more than one gene in the locus where a read
   was mapped, names/ids are separated by a semicolon followed by space ('; ').
   
   The resulting data may be used to check whether the gene name provided
   in a read sequence id (qname) may be found among names obtained from
   Ensembl database based on a read location.
*/
process analyseGenes {
    conda      params.condaEnvPy
    publishDir 'output', mode: 'link'
    
    input:
        tuple path(mappingTsvFile), path(genomeGtfFile)
    
    exec:
        genesTsvFile = 'gene_analysis.tsv.gz'
    
    output:
        path genesTsvFile
    
    script:
        template 'analyse_genes.py'
}

/* Using TCGAbiolinks R Bioconductor module obtaines expression matrices for
   samples, the name of which are given in the samplesTxtFile file. Data on
   gene ids is obtained from the file generated by the analyseGenes process.
   
   Consumes a tuple of the path emitted by the analyseGenes process combined
   with a path to the input samplesTxtFile that indicates the location of
   a text file containing sample ids/names (one per line). Emits a path to
   a gzipped TSV file (matrixTsvFile).
   
   The first column of the output file is an index column that contains gene ids
   and the remaining columns contain expression data for the samples in the order
   their ids are provided in the input file.
*/
process fetchMatrix {
    conda      params.condaEnvR
    publishDir 'output', mode: 'link'
    
    input:
        tuple path(genesTsvFile), path(samplesTxtFile)
    
    exec:
        matrixTsvFile = 'gene_matrix.tsv.gz'
    
    output:
        path matrixTsvFile
    
    script:
        template 'fetch_matrix.r'
}

/* The workflow description. Process are overlaid in a linear manner. The output
   of one is fed to the next. The entry channel consumes the path to a FASTA file
   that contains reference sequences the input reads are mapped to. Before running
   the mapReads process the channel is combined with a path to the read file.
   A similar thing happens before the analyseGenes process and a path to
   the annotation GFT file as well as before the fetchMatrix process and
   a path to a text file with TCGA sample ids.
*/
workflow {
   Channel.fromPath(params.genomeFastaFile)
   | buildIndex
   | combine( Channel.fromPath(params.readsFile) )
   | mapReads
   | filterMapping
   | analyseMapping
   | combine( Channel.fromPath(params.genomeGtfFile) )
   | analyseGenes
   | combine( Channel.fromPath(params.samplesTxtFile) )
   | fetchMatrix
}

