#!/bin/bash

# =================================================================================
# Skript na orezavanie a filtrovanie parovych citani panelu OncoZoom Cancer Hotspot
#
# Vykona tiez MultiQC, ktory vytvori sumarny report obsahujuci informaciu o mnozstve
# odfiltrovanych citani a dovodoch ich filtrovania.
# =================================================================================

### NACITANIE MODULOV #######
module add fastp
module add python36-modules-gcc

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

### POTREBNE CESTY ##########

INDIR="..."
OUTDIR="..."
REPORT_DIR="..."

# Vytvorenie vystupnych priecinkov, ak neexistuju
mkdir -p "$OUTDIR" "$REPORT_DIR"


### fastp #####################

echo "Spusta fastp"

# Pre kazde R1 fastq najde R2 a spracuje ich
for R1 in "$INDIR"/*_R1.fastq.gz; do
    SAMPLE=$(basename "$R1" _R1.fastq.gz)
    R2="$INDIR/${SAMPLE}_R2.fastq.gz"

    echo "Spracuva $SAMPLE"

    fastp \
        -i "$R1" \
        -I "$R2" \
        -o "$OUTDIR/${SAMPLE}_R1_fastp.fastq.gz" \
        -O "$OUTDIR/${SAMPLE}_R2_fastp.fastq.gz" \
        -h "$REPORT_DIR/${SAMPLE}_fastp.html" \
        -j "$REPORT_DIR/${SAMPLE}_fastp.json" \
	--trim_poly_g \
        --cut_tail --cut_tail_mean_quality 30 \
	--average_qual 30 \
	--adapter_sequence AGATCGGAAGAGCACACGTCTGAA \
	--adapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGG \
	--length_required 30	

done

### MultiQC ####################

echo "Spusta MultiQC"

multiqc "$REPORT_DIR" -o "$REPORT_DIR"


echo "Hotovo, vystupne subory su v priecinku $OUTDIR a $REPORT_DIR"
