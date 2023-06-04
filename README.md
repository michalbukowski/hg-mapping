# hg-mapping
A simple Nextflow workflow designed to map short sequences to human genome and perform a few basic analyses of the mapping results. The short sequences may be of different origin, e.g. sgRNA sequences or sequencing short reads (for simplicity such short sequences are referred to as "reads" in this documentation). If you feel that the provided here help is not enough, see detailed comments in the workflow files.

### Contents
1. [Environment setup](#1)<br>
&nbsp;&nbsp;&nbsp;&nbsp;1.1. [Manual environment configuration](#1.1)<br>
&nbsp;&nbsp;&nbsp;&nbsp;1.2. [Automatic environment setup with Docker](#1.2)<br>
2. [Workflow detailed description](#2)<br>
&nbsp;&nbsp;&nbsp;&nbsp;2.1. [Workflow configuration details](#2.1)<br>
&nbsp;&nbsp;&nbsp;&nbsp;2.2. [Workflow design](#2.2)<br>
3.  [Running the workflow](#3)

### <a name="1">1. Environment setup</a>
The workflow is intendent to be run in Bash on Linux operating systems. Miniconda or Anaconda installation is required. The workflow has been tested using Miniconda installation (conda 23.3.1) and the following packages:
* python 3.9.16
* pip 23.1.2
* numpy 1.24.3
* pandas 2.0.2
* pyensembl 2.2.8
* r-base 4.2.0
* bioconductor-tcgabiolinks 2.25.3
* bowtie2 2.5.1
* samtools 1.17
* nextflow 23.04.1

##### <a name="1.1">1.1. Manual environment configuration</a>
To run the workflow three steps must be taken. Firstly, Nextflow must be installed in the conda environment the pipeline will be launched from (e.g. the base environment):
```bash
conda install -c bioconda -c conda-forge nextflow==23.04.1
```

Then `workflow-env` environment should be created using `conda/workflow-env.txt` file:
```bash
conda create --name workflow-env --file conda/workflow-env.txt
```
Important: `params.condaEnv` in `nextflow.config` file must indicated the path of the `workflow-env`. The default setting is `params.condaEnv = '/miniconda3/envs/workflow-env'`, and it is fit for usage in a Docker container. If you use the workflow in another way, please remember to change that to a valid path.

Finally, the `pyensembl` package is supposed to be installed using `pip` into the `workflow-env` environment:
```bash
conda activate workflow-env
pip install pyensembl==2.2.8
conda deactivate workflow-env
```
or
```bash
<path_to_workflow-env_directory>/bin/pip install pyensembl==2.2.8
```

##### <a name="1.2">1.2. Automatic environment setup with Docker</a>
The following setup was tested using Docker ver. 24.0.2. In the main workflow directory there is a `Dockerfile`. It allows for creation of a Docker image (based on ubuntu:22.04 image from the Docker library) as well as for a completely automatic setup of the workflow environment. All the workflow files are gathered in `/hg-mapping` image location. To create such an image (named here `workflow-ubuntu:22.04`) clone the repository and run the following command in the workflow main directory where the `Dockerfile` is present:
```bash
docker build -t workflow-ubuntu:22.04 ./
```

Then you can create a container and run it, e.g. interactively like this:
```
docker run -it workflow-ubuntu:22.04
```

You can download a ready-to-use `workflow-ubuntu:22.04` image [here](https://drive.google.com/file/d/1hm3M41m0Ps8cAvBeXfOuJvnovGW47ezE/view?usp=drive_link) (2.3&nbsp;GB).

### <a name="2">2. Workflow detailed description</a>
##### <a name="2.1">2.1. Workflow tree</a>
Below you will find a tree of all workflow files that are provided. When the workflow is launched, the output files will be published in a subdirectory named `output`.
```
<workflow_location>/
├── conda/
│   └── workflow-env.txt
├── input/
│   ├── library.fa
│   └── TCGA_samples.txt
├── templates/
│   ├── analyse_genes.py
│   ├── analyse_mapping.py
│   └── fetch_matrix.r
├── nextflow.config
└── main.nf
```

##### <a name="2.2">2.2. Workflow configuration details</a>
The workflow is ready to run and perform its tasks using files that are listed in the table below. The file paths are assigned to Nextflow parameters (params) in the `nextflow.config` file. All output files will be published in the `output` subdirectory. For more information see comments in the workflow files (`main.nf` and `nextflow.config`) as well as the next section.

In order to process other than provided files, change the paths assigned to Nexflow params in the `nexflow.config` file. Should you need to process input files and save the output files from/to external locations (in respect to the container), consider using bind mount mechanism when running `docker run` command (the `-v`/`--volume` parameter) to bind external locations to the `input` and `output` workflow subdirectories inside of a container.
| Nextflow parameter | File path | Use |
| - | - | - |
| `params.readsFile` | `input/library.fa` | Reads to be mapped delivered in a FASTA or a FASTQ file. |
| `params.samplesTxtFile` | `input/TCGA_samples.txt` | A list of TCGA sample ids in a text file. |
| `params.genomeFastaFile` | [`Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz`](https://ftp.ensembl.org/pub/release-109/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz) remote (foreign) file from Ensembl FTP location | FASTA file with human genome GRCh38 (release 109) primary assembly reference sequences (not masked) for mapping the reads to. |
| `params.genomeGtfFile` | [`Homo_sapiens.GRCh38.109.gtf.gz`](https://ftp.ensembl.org/pub/release-109/gtf/homo_sapiens/Homo_sapiens.GRCh38.109.gtf.gz) remote (foreign) file from Ensembl FTP location | GTF file providing annotations for the reference sequences. |
| `params.chromosomeYFile` | [`Homo_sapiens.GRCh38.dna.chromosome.Y.fa.gz`](https://ftp.ensembl.org/pub/release-109/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.chromosome.Y.fa.gz) remote (foreign) file from Ensembl FTP location | A short and thus quickly processable reference sequence of the human chromosome Y in a FASTA file that is intended to be used for testing purposes (when swapped with `params.genomeFastaFile` in `main.nf` file). |

##### <a name="2.3">2.3. Workflow design</a>
The workflow consists of the following stages/processes:
| No. | Process name | Task description |
| - | - | - |
| 1. | `buildIndex` |  Using `bowtie-build`, builds reference sequence index from sequences in the input `params.genomeFastaFile`. Uses `index/genome` as the index prefix and saves the index to the `output` subdirectory. |
| 2. | `mapReads` | Using `bowtie2`, maps reads from the `params.readsFile` to `params.genomeFastaFile` reference. Saves the results to a gzipped SAM file `output/mapping.sam.gz`. |
| 3. | `filterMapping` | Using `samtools view`, filters the mapping results in respect to MAPQ values (>= 30). Saves the results to a gzipped SAM file `output/mapping_filtered.sam.gz`. |
| 4. | `analyseMapping`  | Using `templates/analyse_mapping.py` Python script, analyses filtered mapping results in order to calculate the end positions of mapped reads (based on CIGAR values) and the strand reads were mapped to (based on FLAG values). Saves the results to a gzipped TSV file `mapping_analysis.tsv.gz`. Next to QNAME, FLAG, RNAME, POS, MAPQ, CIGAR columns from the SAM input file (names are converted to lower case: `qname`, `flag`, `rname`, `pos`, `mapq`, `cigar`), renders the `end` (based on CIGAR) and `strand` (based on FLAG) columns that denote respectively the end locations of reads within the reference sequence and the strand of the reference sequence reads were mapped to. |
| 5. | `analyseGenes` | Using `templates/analyse_genes.py` Python script that utilises PyEnsembl module, obtains information of genes the input reads were mapped within. It uses `params.genomeGtfFile` that indicates the location of the file with annotations for the reference sequences. Saves the results to a gzipped TSV file `gene_analysis.tsv.gz`. The output file contains `qname` column (a read sequence id) next to `gene_names` and `gene_ids` columns that contain respectively gene names and their ids obtained from Ensembl database. If there is more than one gene in the locus where a given read was mapped, names/ids are separated by a semicolon followed by space (`'; '`). The resulting data may be used to check whether the gene name provided in a read sequence id (_qname_) may be found among names obtained from Ensembl database based on a read location. | 
| 6. | `fetchMatrix` | Using `templates/fetch_matrix.r` R script that utilises TCGAbiolinks R Bioconductor module, obtains expression matrices for samples, the name of which are given in the `params.samplesTxtFile`. Saves the results to a gzipped TSV file `gene_matrix.tsv.gz`. The first column of the output file is an index column that contains gene ids (selected during the previous stage), and the remaining columns contain expression data for the samples in the order their ids are provided in the input `params.samplesTxtFile`. |

### 3. <a name="3">Running the workflow</a>
Once the environment is ready and the configuration optionally adjusted to your needs, run the workflow:
```
nextflow main.nf
```
