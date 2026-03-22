#!/bin/bash -l

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

# Kontrola existencie indexov referencneho genomu pred spustenim
if [[ ! -f "$REF_FASTA" ]]; then
    echo "Chyba: Referencny genom neexistuje na ceste: $REF_FASTA"
    exit 1
fi

if [[ ! -f "${REF_FASTA}.bwt" ]]; then
    echo "Chyba: Chyba BWA index (.bwt) v priecinku s referenciou!"
    echo "Spusti: bwa index $REF_FASTA"
    exit 1
fi

if [[ ! -f "${REF_FASTA}.fai" ]]; then
    echo "Chyba: Chyba Samtools index (.fai)!"
    echo "Spusti: samtools faidx $REF_FASTA"
    exit 1
fi

DICT_FILE="${REF_FASTA%.*}.dict"
if [[ ! -f "$DICT_FILE" ]]; then
    echo "Chyba: Chyba GATK dictionary (.dict)!"
    echo "Spusti: gatk CreateSequenceDictionary -R $REF_FASTA"
    exit 1
fi

# Kontrola existencie suboru s cielovymi oblastami
if [[ ! -f "$PANEL_BED" ]]; then
    echo "Chyba: BED subor s panelom neexistuje: $PANEL_BED"
    exit 1
fi

# Kontrola existencie vstupov pre Variant Calling
if [[ ! -f "$TSV_FILE" ]]; then
    echo "Chyba: TSV tabulka neexistuje: $TSV_FILE"
    exit 1
fi

if [[ ! -f "$PON" || ! -f "$GNOMAD" ]]; then
    echo "Chyba: Chybaju referencie pre Mutect2 (PON alebo gnomAD)."
    exit 1
fi

if [[ ! -f "$VEP_SIF" || ! -d "$VEP_CACHE" ]]; then
    echo "Chyba: Chyba Singularity image pre VEP ($VEP_SIF) alebo VEP Cache ($VEP_CACHE)."
    exit 1
fi

mkdir -p "$RESULTS_DIR/01_qc" "$RESULTS_DIR/02_fastp" "$RESULTS_DIR/03_mapping" "$RESULTS_DIR/04_primer_trim" "$RESULTS_DIR/05_coverage" "$RESULTS_DIR/06_variant_calling" "$RESULTS_DIR/07_annotation" "$LOG_DIR"

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

"$SCRIPT_DIR/05_coverage_metrics.sh" \
    --indir "$RESULTS_DIR/04_primer_trim" \
    --bed "$PANEL_BED" \
    --outdir "$RESULTS_DIR/05_coverage" \
    --threads "$THREADS_MAP" \
    --logdir "$LOG_DIR"

"$SCRIPT_DIR/06_variant_calling_mutect2.sh" \
    --indir "$RESULTS_DIR/04_primer_trim" \
    --tsv "$TSV_FILE" \
    --ref "$REF_FASTA" \
    --bed "$PANEL_BED" \
    --pon "$PON" \
    --gnomad "$GNOMAD" \
    --outdir "$RESULTS_DIR/06_variant_calling" \
    --threads "$THREADS_MUTECT" \
    --logdir "$LOG_DIR"

"$SCRIPT_DIR/07_variant_annotation_vep.sh" \
    --indir "$RESULTS_DIR/06_variant_calling" \
    --tsv "$TSV_FILE" \
    --vep-sif "$VEP_SIF" \
    --vep-cache "$VEP_CACHE" \
    --ref "$REF_FASTA" \
    --outdir "$RESULTS_DIR/07_annotation" \
    --threads "$THREADS_VEP" \
    --logdir "$LOG_DIR"

echo "Pipeline 01-07 uspesne dokoncena."
