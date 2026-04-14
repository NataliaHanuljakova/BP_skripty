#!/bin/bash -l

# ===================================================================
# Skript pre Variant Annotation (VEP)
# Filtruje PASS varianty a anotuje ich pomocou Ensembl VEP
# Triedi vystupy do priecinkov podla 'disease' stlpca v samples.tsv
# Vytvara zlucenu Master tabulku vsetkych pacientov
# ===================================================================

set -euo pipefail

usage() {
cat <<EOF
Pouzitie:
  $(basename "$0") \
    --indir <path> \
    --tsv <samples.tsv> \
    --vep-sif <path_to_sif> \
    --vep-cache <path> \
    --ref <path> \
    --outdir <path> \
    [--threads <n>] \
    [--logdir <path>]
EOF
}

INDIR=""; TSV=""; VEP_SIF=""; VEP_CACHE=""; REF=""; OUTDIR=""; THREADS=4; LOGDIR="logs"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --indir) INDIR="$2"; shift 2 ;;
        --tsv) TSV="$2"; shift 2 ;;
        --vep-sif) VEP_SIF="$2"; shift 2 ;;
        --vep-cache) VEP_CACHE="$2"; shift 2 ;;
        --ref) REF="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        --threads) THREADS="$2"; shift 2 ;;
        --logdir) LOGDIR="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Neznamy parameter: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$INDIR" || -z "$TSV" || -z "$VEP_SIF" || -z "$VEP_CACHE" || -z "$REF" || -z "$OUTDIR" ]]; then
    echo "Chyba: Chybaju povinne parametre."
    exit 1
fi

mkdir -p "$OUTDIR" "$LOGDIR"
RUN_ID="$(date +%Y%m%d_%H%M%S)_07_vep_annotation"
LOG_FILE="$LOGDIR/${RUN_ID}.log"

module load bcftools 2>/dev/null || true

command -v bcftools >/dev/null || { echo "bcftools chyba"; exit 1; }
command -v singularity >/dev/null || { echo "singularity chyba"; exit 1; }

echo "[INFO] Start: $(date)" | tee "$LOG_FILE"

PATIENTS=$(awk 'NR>1 {print $1}' "$TSV" | sort -u)

for PATIENT_ID in $PATIENTS; do
    echo "============================" | tee -a "$LOG_FILE"

    DISEASE=$(awk -v p="$PATIENT_ID" '$1==p {print $4}' "$TSV" | head -n 1)
    [[ -z "$DISEASE" ]] && DISEASE="Unknown"

    PATIENT_OUTDIR="$OUTDIR/$DISEASE"
    mkdir -p "$PATIENT_OUTDIR"

    INPUT_VCF="$INDIR/$DISEASE/${PATIENT_ID}_filtered.vcf.gz"

    if [[ ! -f "$INPUT_VCF" ]]; then
        echo "[WARN] Missing VCF: $PATIENT_ID" | tee -a "$LOG_FILE"
        continue
    fi

    echo "[INFO] Processing $PATIENT_ID ($DISEASE)" | tee -a "$LOG_FILE"

    # ? ŽIADNY PASS FILTER
    ALL_VCF="$PATIENT_OUTDIR/${PATIENT_ID}_all.vcf.gz"
    bcftools view "$INPUT_VCF" -O z -o "$ALL_VCF"
    bcftools index -f "$ALL_VCF"

    VARIANT_COUNT=$(bcftools view -H "$ALL_VCF" | wc -l)
    echo "[INFO] Variant count: $VARIANT_COUNT" | tee -a "$LOG_FILE"

    if [[ "$VARIANT_COUNT" -eq 0 ]]; then
        echo "[WARN] No variants at all for $PATIENT_ID" | tee -a "$LOG_FILE"
        continue
    fi

    # ?? VAF + FILTER map
    MAP_FILE="$PATIENT_OUTDIR/${PATIENT_ID}_info.map"

    bcftools query -f "%CHROM\t%POS\t%REF\t%ALT\t%FILTER\t[%AF]\n" "$ALL_VCF" | \
    awk '{print $1"_"$2"_"$3"/"$4"\t"$5"\t"$6}' > "$MAP_FILE"

    # VEP
    OUTPUT_RAW="$PATIENT_OUTDIR/${PATIENT_ID}_annotated_raw.tsv"

    singularity exec -B /storage "$VEP_SIF" vep \
        --dir_cache "$VEP_CACHE" \
        --fasta "$REF" \
        --input_file "$ALL_VCF" \
        --output_file "$OUTPUT_RAW" \
        --cache --offline --assembly GRCh38 --species homo_sapiens \
        --everything --tab --force_overwrite --no_stats \
        --flag_pick \
        --fork "$THREADS" 2>> "$LOG_FILE"

    # FINAL TSV (pridanie FILTER + VAF)
    OUTPUT_TSV="$PATIENT_OUTDIR/${PATIENT_ID}_annotated.tsv"

    awk -v map="$MAP_FILE" '
    BEGIN {
        FS=OFS="\t";
        while(getline < map > 0) {
            key=$1; filter[key]=$2; vaf[key]=$3
        }
    }
    /^#Uploaded_variation/ {
        print $0, "FILTER", "VAF_sample";
        next
    }
    !/^#/ {
        f = (filter[$1] ? filter[$1] : ".");
        v = (vaf[$1] ? vaf[$1] : "0");
        print $0, f, v
    }' "$OUTPUT_RAW" > "$OUTPUT_TSV"

done

# MASTER TABLE
MASTER_TSV="$OUTDIR/ALL_SAMPLES_master.tsv"
echo "[INFO] Creating master table" | tee -a "$LOG_FILE"

FIRST_TSV=$(find "$OUTDIR" -name "*_annotated.tsv" | sed -n '1p')

if [[ -n "$FIRST_TSV" && -f "$FIRST_TSV" ]]; then

    HEADER=$(grep "^#Uploaded_variation" "$FIRST_TSV" | sed 's/^#//' || true)

    if [[ -n "$HEADER" ]]; then
        echo -e "Patient_ID\tDisease\t$HEADER" > "$MASTER_TSV"
    else
        echo "[ERROR] Header not found in $FIRST_TSV" | tee -a "$LOG_FILE"
        exit 1
    fi

    for DISEASE_DIR in "$OUTDIR"/*/; do
        D_NAME=$(basename "$DISEASE_DIR")

        for TSV_FILE in "$DISEASE_DIR"/*_annotated.tsv; do
            [[ -e "$TSV_FILE" ]] || continue

            P_NAME=$(basename "$TSV_FILE" _annotated.tsv)

            grep -v "^#" "$TSV_FILE" | \
            awk -v p="$P_NAME" -v d="$D_NAME" 'BEGIN{FS=OFS="\t"} {print p, d, $0}' \
            >> "$MASTER_TSV"
        done
    done

    echo "[INFO] Master table OK" | tee -a "$LOG_FILE"

else
    echo "[WARN] No TSV files found" | tee -a "$LOG_FILE"
fi
