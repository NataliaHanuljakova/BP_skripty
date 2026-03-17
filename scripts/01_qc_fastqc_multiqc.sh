#!/usr/bin/env bash

# ==================================================================
# Skript na kontrolu kvality FASTQ suborov pomocou FastQC a MultiQC
# ==================================================================

set -euo pipefail

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

usage() {
	cat <<EOF
Pouzitie:
  $(basename "$0") --indir <path> --outdir <path> [--logdir <path>]

Parametre:
  --indir   Priecinok so vstupnymi *.fastq.gz subormi
  --outdir  Vystupny priecinok pre FastQC a MultiQC reporty
  --logdir  Priecinok s logmi (default: logs)
  --help    Zobrazi tuto napovedu
EOF
}

INDIR=""
OUTDIR=""
LOGDIR="logs"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--indir) INDIR="$2"; shift 2 ;;
		--outdir) OUTDIR="$2"; shift 2 ;;
		--logdir) LOGDIR="$2"; shift 2 ;;
		--help|-h) usage; exit 0 ;;
		*) echo "Neznamy parameter: $1"; usage; exit 1 ;;
	esac
done

if [[ -z "$INDIR" || -z "$OUTDIR" ]]; then
	echo "Chyba: --indir a --outdir su povinne."
	usage
	exit 1
fi

if [[ ! -d "$INDIR" ]]; then
	echo "Chyba: vstupny priecinok neexistuje: $INDIR"
	exit 1
fi

if [[ "$(type -t module || true)" != "" ]]; then
	module load fastqc || true
	module load python36-modules-gcc || true
fi

if ! command -v fastqc >/dev/null 2>&1; then
	echo "Chyba: fastqc nie je dostupny v PATH."
	exit 1
fi

if ! command -v multiqc >/dev/null 2>&1; then
	echo "Chyba: multiqc nie je dostupny v PATH."
	exit 1
fi

mkdir -p "$OUTDIR" "$LOGDIR"

mapfile -t FASTQ_FILES < <(find "$INDIR" -maxdepth 1 -type f -name "*.fastq.gz" | sort)
if [[ ${#FASTQ_FILES[@]} -eq 0 ]]; then
	echo "Chyba: v $INDIR neboli najdene ziadne *.fastq.gz subory."
	exit 1
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)_01_qc"
LOG_FILE="$LOGDIR/${RUN_ID}.log"

{
	echo "[INFO] Spustenie: $(date --iso-8601=seconds)"
	echo "[INFO] INDIR=$INDIR"
	echo "[INFO] OUTDIR=$OUTDIR"
	echo "[INFO] Pocet FASTQ suborov: ${#FASTQ_FILES[@]}"
	echo "[INFO] fastqc version: $(fastqc --version 2>&1)"
	echo "[INFO] multiqc version: $(multiqc --version 2>&1)"
} | tee "$LOG_FILE"

fastqc "${FASTQ_FILES[@]}" -o "$OUTDIR" 2>&1 | tee -a "$LOG_FILE"
multiqc "$OUTDIR" -o "$OUTDIR" 2>&1 | tee -a "$LOG_FILE"

echo "Hotovo, vystupne subory su v priecinku $OUTDIR"
echo "Log: $LOG_FILE"
