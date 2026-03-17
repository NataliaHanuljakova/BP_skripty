#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Pouzitie:
  $(basename "$0") --config <config/params.env>
EOF
}

CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Neznamy parameter: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Chyba: --config je povinny parameter."
    usage
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Chyba: konfiguracny subor neexistuje: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

mkdir -p "$RESULTS_DIR/01_qc" "$RESULTS_DIR/02_fastp" "$RESULTS_DIR/03_mapping" "$RESULTS_DIR/04_primer_trim" "$LOG_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/01_qc_fastqc_multiqc.sh" \
    --indir "$RAW_FASTQ_DIR" \
    --outdir "$RESULTS_DIR/01_qc" \
    --logdir "$LOG_DIR"

"$SCRIPT_DIR/02_trim_filter_fastp.sh" \
    --indir "$RAW_FASTQ_DIR" \
    --outdir "$RESULTS_DIR/02_fastp" \
    --report-dir "$RESULTS_DIR/02_fastp" \
    --threads "$THREADS_FASTP" \
    --logdir "$LOG_DIR"

"$SCRIPT_DIR/03_map_bwa_samtools.sh" \
    --ref-fasta "$REF_FASTA" \
    --fastqdir "$RESULTS_DIR/02_fastp" \
    --outdir "$RESULTS_DIR/03_mapping" \
    --threads "$THREADS_MAP" \
    --logdir "$LOG_DIR"

"$SCRIPT_DIR/04_primer_trim_samtools.sh" \
    --indir "$RESULTS_DIR/03_mapping" \
    --primer-bed "$PRIMER_BED" \
    --outdir "$RESULTS_DIR/04_primer_trim" \
    --threads "$THREADS_TRIM" \
    --logdir "$LOG_DIR"

echo "Pipeline 01-04 uspesne dokoncena."
