# syntax=docker/dockerfile:1

# Created by Michal Bukowski (michal.bukowski@tuta.io) under GPL-3.0 license.
# Dockerfile allowing for containerisation of hg-mapping Nextflow workflow.

# Build a new image based on ubuntu:22.04 image from the Docker library.
FROM ubuntu:22.04

# Set arguments identyfying image paths for the Nextflow workflow directory
# (WORKFLOW_DIR), Miniconda directory (MINICONDA_DIR) and names for the
# conda environments that will be used by the workflow (PY_ENV_NAME and R_ENV_NAME).
# Important: MINICONDA_DIR/envs/PY_ENV_NAME and MINICONDA_DIR/envs/R_ENV_NAME
# must be equivalent to locations of conda environments that are used by
# the workflow and are defined in nextflow.config file respectively as
# params.condaEnvPy and params.condaEnvR.
ARG WORKFLOW_DIR=/hg-mapping
ARG MINICONDA_DIR=/miniconda3
ARG PY_ENV_NAME=workflow-py
ARG R_ENV_NAME=workflow-r

# Set the working directory to the image workflow location and copy the workflow
# directories and files to that location (including conda subdirectory
# containing the workflow conda environment files).
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
# - create the workflow conda environments from conda/workflow-py.txt and
#   conda/workflow-r.txt files
# - using pip package manager install in the first environment PyEnsembl (ver. 2.2.8)
RUN apt update
RUN apt install -y wget
RUN wget "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
RUN bash Miniconda3-latest-Linux-x86_64.sh -bp $MINICONDA_DIR
RUN rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH="$MINICONDA_DIR/bin:${PATH}"
RUN conda install -y -c bioconda -c conda-forge nextflow==23.04.1
RUN conda create -y --prefix $MINICONDA_DIR/envs/$PY_ENV_NAME --file conda/workflow-py.txt
RUN conda create -y --prefix $MINICONDA_DIR/envs/$R_ENV_NAME  --file conda/workflow-r.txt
RUN yes | $MINICONDA_DIR/envs/$PY_ENV_NAME/bin/pip install pyensembl==2.2.8

