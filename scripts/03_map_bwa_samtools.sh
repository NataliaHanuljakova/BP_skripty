#!/usr/bin/env bash

# ===============================================================
# Skript na mapovanie citani na referencny genom GRCh38
# Subory budu tiez zoradene a indexovane
# ===============================================================

set -euo pipefail

# Nacitanie modulov
module load bwa
module load samtools

usage() {
    cat <<EOF
Pouzitie:
  $(basename "$0") --ref-fasta <path> --fastqdir <path> --outdir <path> [--threads <n>] [--logdir <path>]

Parametre:
  --ref-fasta  Referencny FASTA subor (napr. genomes/GRCh38/GRCh38.fa)
  --fastqdir   Priecinok s *_R1_fastp.fastq.gz a *_R2_fastp.fastq.gz
  --outdir     Vystupny priecinok pre .sorted.bam/.bai
  --threads    Pocet vlakien pre bwa/samtools (default: 8)
  --logdir     Priecinok s logmi (default: logs)
  --help       Zobrazi tuto napovedu
EOF
}

REF_FASTA=""
FASTQDIR=""
OUTDIR=""
THREADS=8
LOGDIR="logs"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ref-fasta) REF_FASTA="$2"; shift 2 ;;
        --fastqdir) FASTQDIR="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        --threads) THREADS="$2"; shift 2 ;;
        --logdir) LOGDIR="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Neznamy parameter: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$REF_FASTA" || -z "$FASTQDIR" || -z "$OUTDIR" ]]; then
    echo "Chyba: --ref-fasta, --fastqdir a --outdir su povinne."
    usage
    exit 1
fi

if [[ ! -f "$REF_FASTA" ]]; then
    echo "Chyba: referencny subor neexistuje: $REF_FASTA"
    exit 1
fi

if [[ ! -d "$FASTQDIR" ]]; then
    echo "Chyba: FASTQ priecinok neexistuje: $FASTQDIR"
    exit 1
fi

if [[ "$(type -t module || true)" != "" ]]; then
    module load bwa || true
    module load samtools || true
fi

if ! command -v bwa >/dev/null 2>&1; then
    echo "Chyba: bwa nie je dostupny v PATH."
    exit 1
fi

if ! command -v samtools >/dev/null 2>&1; then
    echo "Chyba: samtools nie je dostupny v PATH."
    exit 1
fi

mkdir -p "$OUTDIR" "$LOGDIR"

mapfile -t R1_FILES < <(find "$FASTQDIR" -maxdepth 1 -type f -name "*_R1_fastp.fastq.gz" | sort)
if [[ ${#R1_FILES[@]} -eq 0 ]]; then
    echo "Chyba: v $FASTQDIR neboli najdene subory *_R1_fastp.fastq.gz."
    exit 1
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)_03_mapping"
LOG_FILE="$LOGDIR/${RUN_ID}.log"

{
    echo "[INFO] Spustenie: $(date --iso-8601=seconds)"
    echo "[INFO] REF_FASTA=$REF_FASTA"
    echo "[INFO] FASTQDIR=$FASTQDIR"
    echo "[INFO] OUTDIR=$OUTDIR"
    echo "[INFO] THREADS=$THREADS"
    echo "[INFO] bwa version: $(bwa 2>&1 | head -n 1)"
    echo "[INFO] samtools version: $(samtools --version | head -n 1)"
} | tee "$LOG_FILE"

echo "Mapovanie BWA-MEM" | tee -a "$LOG_FILE"

for R1 in "${R1_FILES[@]}"; do
    SAMPLE=$(basename "$R1" _R1_fastp.fastq.gz)
    R2="$FASTQDIR/${SAMPLE}_R2_fastp.fastq.gz"

    if [[ ! -f "$R2" ]]; then
        echo "[WARN] Subor R2 chyba pre $SAMPLE, preskakujem." | tee -a "$LOG_FILE"
        continue
    fi

    echo "Spracuva $SAMPLE" | tee -a "$LOG_FILE"
    RG="@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA\tLB:OncoZoom"

    bwa mem -t "$THREADS" -R "$RG" "$REF_FASTA" "$R1" "$R2" \
        | samtools sort -@ "$THREADS" -o "$OUTDIR/${SAMPLE}.sorted.bam" - 2>&1 | tee -a "$LOG_FILE"

    samtools index -@ "$THREADS" "$OUTDIR/${SAMPLE}.sorted.bam" 2>&1 | tee -a "$LOG_FILE"
    samtools flagstat -@ "$THREADS" "$OUTDIR/${SAMPLE}.sorted.bam" > "$OUTDIR/${SAMPLE}.flagstat.txt"
done

echo "Mapovanie hotovo, vystupy su v $OUTDIR"
echo "Log: $LOG_FILE"

# Upratanie modulov
module load bwa
module load samtools
