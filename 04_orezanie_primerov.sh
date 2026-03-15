#!/bin/bash

# ========================================================
# Skript na orezanie primerov po mapovani pomocou Samtools 
# ========================================================

### NACITANIE MODULOV ###################
module load samtools

### POTREBNE CESTY ######################

INDIR="..."
PRIMER_BED="primers.bed"
OUTDIR="..."

# Vytvorenie výstupného priecinku, ak neexistuje

mkdir -p "$OUTDIR"


### OREZANIE PRIMEROV ####################

for bam in "$INDIR"/*.sorted.bam; do
    base=$(basename "$bam" .sorted.bam)

    echo "Spracovava vzorku $base"

    samtools ampliconclip --threads 4 --soft-clip \
        -b "$PRIMER_BED" \
        "$bam" \
        -o "$OUTDIR/${base}.tmp.bam"

    # Opatovne zoradenie podla suradnic
    samtools sort --threads 4 \
        "$OUTDIR/${base}.tmp.bam" \
        -o "$OUTDIR/${base}.trimmed.bam"

    # Odstranenie docasneho suboru
    rm "$OUTDIR/${base}.tmp.bam"

    # Indexovanie noveho zoradeneho suboru
    samtools index -@ 4 "$OUTDIR/${base}.trimmed.bam"

done

echo "Hotovo, subory v priecinku $OUTDIR "
