#!/bin/bash

# ===============================================================
# Skript na mapovanie citani na referencny genom GRCh38
# Subory budu tiez zoradene a indexovane
# ===============================================================

### NACITANIE MODULOV ####################
module load bwa
module load samtools

### POTREBNE CESTY #######################

REF_DIR="genomes/GRCh38"
FASTQDIR="..."
OUTDIR="..."

# Vytvorenie vystupneho priecinku, ak neexistuje
mkdir -p "$OUTDIR"

cd "$SCRATCHDIR" || exit 1

# Kopirovanie FASTQ suborov, referencie a indexovych suborov do scratchu
cp "$REF_DIR"/GRCh38.fa* .
cp "$FASTQDIR"/*_fastp.fastq.gz .

### MAPOVANIE BWA-MEM #####################
echo "mapovanie BWA-MEM"

# Prejde vsetky R1 subory
for R1 in *_R1_fastp.fastq.gz; do
    SAMPLE=$(basename "$R1" _R1_fastp.fastq.gz)
    R2="${SAMPLE}_R2_fastp.fastq.gz"

    if [ ! -f "$R2" ]; then
        echo "subor R2 chyba pre $SAMPLE"
        continue
    fi

    echo "Spracuva $SAMPLE"

    # definicia Read Group retazca
    RG="@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA\tLB:OncoZoom"


    # Pipe do samtools sort (zoradenie)
    bwa mem -t 8 -R "$RG" GRCh38.fa "$R1" "$R2" \
        | samtools sort -@ 8 -o "${SAMPLE}.sorted.bam"

    # Indexovanie BAM suboru
    samtools index -@ 8 "${SAMPLE}.sorted.bam"

    echo "$SAMPLE hotovo."
done

### PRESUN VYSLEDKOV ######################
echo "Kopiruje BAM a BAI do $OUTDIR"
cp *.bam "$OUTDIR"
cp *.bai "$OUTDIR"

clean_scratch

echo "Mapovanie hotovo, vystupy su v $OUTDIR"
