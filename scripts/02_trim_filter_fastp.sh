#!/bin/bash -l

# =================================================================================
# Skript na orezavanie a filtrovanie parovych citani panelu OncoZoom Cancer Hotspot
#
# Vykona tiez MultiQC, ktory vytvori sumarny report obsahujuci informaciu o mnozstve
# odfiltrovanych citani a dovodoch ich filtrovania.
# =================================================================================

set -euo pipefail

# Nacitanie modulov
module load fastp 
module load python36-modules-gcc
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

usage() {
        cat <<EOF
Pouzitie:
  $(basename "$0") --indir <path> --outdir <path> --report-dir <path> [--threads <n>] [--logdir <path>]

Parametre:
  --indir       Priecinok so vstupnymi paired-end FASTQ subormi
  --outdir      Vystupny priecinok pre orezane FASTQ
  --report-dir  Priecinok pre fastp JSON/HTML reporty a MultiQC
  --threads     Pocet vlakien pre fastp (default: 4)
  --logdir      Priecinok s logmi (default: logs)
  --help        Zobrazi tuto napovedu
EOF
}

INDIR=""
OUTDIR=""
REPORT_DIR=""
THREADS=4
LOGDIR="logs"

while [[ $# -gt 0 ]]; do
        case "$1" in
                --indir) INDIR="$2"; shift 2 ;;
                --outdir) OUTDIR="$2"; shift 2 ;;
                --report-dir) REPORT_DIR="$2"; shift 2 ;;
                --threads) THREADS="$2"; shift 2 ;;
                --logdir) LOGDIR="$2"; shift 2 ;;
                --help|-h) usage; exit 0 ;;
                *) echo "Neznamy parameter: $1"; usage; exit 1 ;;
        esac
done

if [[ -z "$INDIR" || -z "$OUTDIR" || -z "$REPORT_DIR" ]]; then
        echo "Chyba: --indir, --outdir a --report-dir su povinne."
        usage
        exit 1
fi

if [[ ! -d "$INDIR" ]]; then
        echo "Chyba: vstupny priecinok neexistuje: $INDIR"
        exit 1
fi

if [[ "$(type -t module || true)" != "" ]]; then
        module load fastp || true
        module load python36-modules-gcc || true
fi

if ! command -v fastp >/dev/null 2>&1; then
        echo "Chyba: fastp nie je dostupny v PATH."
        exit 1
fi

if ! command -v multiqc >/dev/null 2>&1; then
        echo "Chyba: multiqc nie je dostupny v PATH."
        exit 1
fi

mkdir -p "$OUTDIR" "$REPORT_DIR" "$LOGDIR"

mapfile -t R1_FILES < <(find "$INDIR" -maxdepth 1 -type f -name "*_R1.fastq.gz" | sort)
if [[ ${#R1_FILES[@]} -eq 0 ]]; then
        echo "Chyba: v $INDIR neboli najdene subory *_R1.fastq.gz."
        exit 1
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)_02_trim_filter"
LOG_FILE="$LOGDIR/${RUN_ID}.log"

{
        echo "[INFO] Spustenie: $(date --iso-8601=seconds)"
        echo "[INFO] INDIR=$INDIR"
        echo "[INFO] OUTDIR=$OUTDIR"
        echo "[INFO] REPORT_DIR=$REPORT_DIR"
        echo "[INFO] THREADS=$THREADS"
        echo "[INFO] fastp version: $(fastp --version 2>&1)"
        echo "[INFO] multiqc version: $(multiqc --version 2>&1)"
} | tee "$LOG_FILE"

echo "Spusta fastp" | tee -a "$LOG_FILE"

for R1 in "${R1_FILES[@]}"; do
        SAMPLE=$(basename "$R1" _R1.fastq.gz)
        R2="$INDIR/${SAMPLE}_R2.fastq.gz"

        if [[ ! -f "$R2" ]]; then
                echo "[WARN] Chyba parovy subor R2 pre $SAMPLE, preskakujem." | tee -a "$LOG_FILE"
                continue
        fi

        echo "Spracuva $SAMPLE" | tee -a "$LOG_FILE"

        fastp \
                --thread "$THREADS" \
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
                --length_required 30 2>&1 | tee -a "$LOG_FILE"
done

echo "Spusta MultiQC" | tee -a "$LOG_FILE"
multiqc "$REPORT_DIR" -o "$REPORT_DIR" 2>&1 | tee -a "$LOG_FILE"

echo "Hotovo, vystupne subory su v priecinku $OUTDIR a $REPORT_DIR"
echo "Log: $LOG_FILE"

# Upratanie modulov
module unload fastp 
module unload python36-modules-gcc
