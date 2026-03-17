#!/usr/bin/env bash

# ========================================================
# Skript na orezanie primerov po mapovani pomocou Samtools
# ========================================================

set -euo pipefail

usage() {
    cat <<EOF
Pouzitie:
  $(basename "$0") --indir <path> --primer-bed <path> --outdir <path> [--threads <n>] [--logdir <path>]

Parametre:
  --indir       Priecinok so vstupnymi *.sorted.bam subormi
  --primer-bed  BED subor s primer oblastami
  --outdir      Vystupny priecinok pre *.trimmed.bam
  --threads     Pocet vlakien pre samtools (default: 4)
  --logdir      Priecinok s logmi (default: logs)
  --help        Zobrazi tuto napovedu
EOF
}

INDIR=""
PRIMER_BED=""
OUTDIR=""
THREADS=4
LOGDIR="logs"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --indir) INDIR="$2"; shift 2 ;;
        --primer-bed) PRIMER_BED="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        --threads) THREADS="$2"; shift 2 ;;
        --logdir) LOGDIR="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Neznamy parameter: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$INDIR" || -z "$PRIMER_BED" || -z "$OUTDIR" ]]; then
    echo "Chyba: --indir, --primer-bed a --outdir su povinne."
    usage
    exit 1
fi

if [[ ! -d "$INDIR" ]]; then
    echo "Chyba: vstupny priecinok neexistuje: $INDIR"
    exit 1
fi

if [[ ! -f "$PRIMER_BED" ]]; then
    echo "Chyba: primer BED subor neexistuje: $PRIMER_BED"
    exit 1
fi

if [[ "$(type -t module || true)" != "" ]]; then
    module load samtools || true
fi

if ! command -v samtools >/dev/null 2>&1; then
    echo "Chyba: samtools nie je dostupny v PATH."
    exit 1
fi

mkdir -p "$OUTDIR" "$LOGDIR"

mapfile -t BAM_FILES < <(find "$INDIR" -maxdepth 1 -type f -name "*.sorted.bam" | sort)
if [[ ${#BAM_FILES[@]} -eq 0 ]]; then
    echo "Chyba: v $INDIR neboli najdene subory *.sorted.bam."
    exit 1
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)_04_primer_trim"
LOG_FILE="$LOGDIR/${RUN_ID}.log"

{
    echo "[INFO] Spustenie: $(date --iso-8601=seconds)"
    echo "[INFO] INDIR=$INDIR"
    echo "[INFO] PRIMER_BED=$PRIMER_BED"
    echo "[INFO] OUTDIR=$OUTDIR"
    echo "[INFO] THREADS=$THREADS"
    echo "[INFO] samtools version: $(samtools --version | head -n 1)"
} | tee "$LOG_FILE"

for bam in "${BAM_FILES[@]}"; do
    base=$(basename "$bam" .sorted.bam)
    tmp_bam="$OUTDIR/${base}.tmp.bam"
    out_bam="$OUTDIR/${base}.trimmed.bam"

    echo "Spracovava vzorku $base" | tee -a "$LOG_FILE"

    samtools ampliconclip --threads "$THREADS" --soft-clip \
        -b "$PRIMER_BED" \
        "$bam" \
        -o "$tmp_bam" 2>&1 | tee -a "$LOG_FILE"

    samtools sort --threads "$THREADS" "$tmp_bam" -o "$out_bam" 2>&1 | tee -a "$LOG_FILE"
    rm -f "$tmp_bam"
    samtools index -@ "$THREADS" "$out_bam" 2>&1 | tee -a "$LOG_FILE"
done

echo "Hotovo, subory su v priecinku $OUTDIR"
echo "Log: $LOG_FILE"
