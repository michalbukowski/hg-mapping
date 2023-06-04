# syntax=docker/dockerfile:1

# Created by Michal Bukowski (michal.bukowski@tuta.io) under GPL-3.0 license.
# Dockerfile allowing for containerisation of hg-mapping Nextflow workflow.

# Build a new image based on ubuntu:22.04 image from the Docker library.
FROM ubuntu:22.04

# Set arguments identyfying image paths for the Nextflow workflow directory
# (WORKFLOW_DIR), Miniconda directory (MINICONDA_DIR) and the name for the
# conda environment that will be used by the workflow (ENV_NAME).
# Important: MINICONDA_DIR/envs/ENV_NAME must be equivalent to the workflow
# conda environment location defined in nextflow.config file.
ARG WORKFLOW_DIR=/hg-mapping
ARG MINICONDA_DIR=/miniconda3
ARG ENV_NAME=workflow-env

# Set the working directory to the image workflow location and copy the workflow
# directories and files to that location (including conda subdirectory
# containing the workflow conda environment file).
WORKDIR              $WORKFLOW_DIR
COPY conda/.         conda
COPY input/.         input
COPY templates/.     templates
COPY main.nf         ./
COPY nextflow.config ./

# Install wget and download the latest version of Miniconda installer. Then:
# - install Miniconda
# - once Miniconda is installed, remove the installer
# - add Miniconda bin directory to PATH
# - in the base conda environment install Nextflow (ver. 23.04.1)
# - create the workflow conda environment from conda/workflow-env.txt file
# - using pip package manager install in that environment PyEnsembl (ver. 2.2.8)
RUN apt update
RUN apt install -y wget
RUN wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
RUN bash Miniconda3-latest-Linux-x86_64.sh -bp $MINICONDA_DIR
RUN rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH="$MINICONDA_DIR/bin:${PATH}"
RUN conda install -y -c bioconda -c conda-forge nextflow==23.04.1
RUN conda create -y --prefix $MINICONDA_DIR/envs/$ENV_NAME --file conda/workflow-env.txt
RUN yes | $MINICONDA_DIR/envs/$ENV_NAME/bin/pip install pyensembl==2.2.8

