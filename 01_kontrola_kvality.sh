#!/bin/bash

# ==================================================================
# Skript na kontrolu kvality FASTQ suborov pomocou FastQC a MultiQC
# ==================================================================

### NACITANIE MODULOV #########
module add fastqc
module add python36-modules-gcc

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

### POTREBNE CESTY ############

INDIR="..."
OUTDIR="..."

# Vytvorenie vystupneho priecinku, ak neexistuje.
mkdir -p "$OUTDIR"


### FastQC ####################

fastqc "$INDIR"/*.fastq.gz -o "$OUTDIR"

### MultiQC ###################

multiqc "$OUTDIR" -o "$OUTDIR"


echo "Hotovo, vystupne subory su v priecinku $OUTDIR "
