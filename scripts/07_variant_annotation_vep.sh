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
  $(basename "$0") 
        --indir <path> 
        --tsv <samples.tsv> 
        --vep-sif <path_to_sif> 
        --vep-cache <path> 
        --ref <path> 
        --outdir <path>
        [--threads <n>] 
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
    echo "Chyba: Chybaju povinne parametre. Spusti s --help"
    exit 1
fi

mkdir -p "$OUTDIR" "$LOGDIR"
RUN_ID="$(date +%Y%m%d_%H%M%S)_07_vep_annotation"
LOG_FILE="$LOGDIR/${RUN_ID}.log"

if [[ "$(type -t module || true)" != "" ]]; then
    module load bcftools || true
fi

if ! command -v bcftools >/dev/null 2>&1; then
    echo "Chyba: bcftools nie je dostupny." | tee -a "$LOG_FILE"
    exit 1
fi
if ! command -v singularity >/dev/null 2>&1; then
    echo "Chyba: singularity nie je dostupne." | tee -a "$LOG_FILE"
    exit 1
fi

{
    echo "[INFO] Spustenie Variant Annotation (VEP): $(date --iso-8601=seconds)"
    echo "[INFO] TSV Tabulka: $TSV"
    echo "[INFO] Hlavny vystupny priecinok: $OUTDIR"
    echo "[INFO] Vlakna (VEP fork): $THREADS"
} | tee "$LOG_FILE"

PATIENTS=$(awk 'NR>1 {print $1}' "$TSV" | sort -u)

for PATIENT_ID in $PATIENTS; do
    echo "==================================================" | tee -a "$LOG_FILE"
    
    DISEASE=$(awk -v p="$PATIENT_ID" '$1==p {print $4}' "$TSV" | head -n 1)
    if [[ -z "$DISEASE" ]]; then
        DISEASE="Unknown"
    fi
    
    PATIENT_OUTDIR="$OUTDIR/$DISEASE"
    mkdir -p "$PATIENT_OUTDIR"

    echo "[INFO] Pacient: $PATIENT_ID | Diagnoza: $DISEASE | Vystup: $PATIENT_OUTDIR" | tee -a "$LOG_FILE"
    
    INPUT_VCF="$INDIR/$DISEASE/${PATIENT_ID}_filtered.vcf.gz"
    
    if [[ ! -f "$INPUT_VCF" ]]; then
        echo "[WARN] Nenasiel sa VCF pre pacienta $PATIENT_ID ($INPUT_VCF). Preskakujem." | tee -a "$LOG_FILE"
        continue
    fi

    PASS_VCF="$PATIENT_OUTDIR/${PATIENT_ID}_pass.vcf.gz"
    bcftools view -f PASS "$INPUT_VCF" -O z -o "$PASS_VCF"
VARIANT_COUNT=$(bcftools view -H "$PASS_VCF" | wc -l)
    
    if [[ "$VARIANT_COUNT" -eq 0 ]]; then
        echo "[WARN] Pacient $PATIENT_ID nema ziadne PASS varianty. Preskakujem." | tee -a "$LOG_FILE"
        rm -f "$PASS_VCF"
        continue
    fi

    bcftools index -f "$PASS_VCF"

    VAF_MAP="$PATIENT_OUTDIR/${PATIENT_ID}_vaf.map"
bcftools query -f "%CHROM\t%POS\t%REF\t%ALT\t[%AF]\n" "$PASS_VCF" | \
awk '{print $1"_"$2"_"$3"/"$4"\t"$5}' > "$VAF_MAP"

    OUTPUT_TSV_RAW="$PATIENT_OUTDIR/${PATIENT_ID}_annotated_raw.tsv"
    
    singularity exec -B /storage "$VEP_SIF" vep \
        --dir_cache "$VEP_CACHE" \
        --fasta "$REF" \
        --input_file "$PASS_VCF" \
        --output_file "$OUTPUT_TSV_RAW" \
        --cache --offline --assembly GRCh38 --species homo_sapiens \
        --everything --tab --force_overwrite --no_stats \
        --flag_pick \
        --fork "$THREADS" 2>> "$LOG_FILE"


    OUTPUT_TSV="$PATIENT_OUTDIR/${PATIENT_ID}_annotated.tsv"
    echo "[INFO] Pripájam VAF stĺpec pre $PATIENT_ID"

    awk -v map="$VAF_MAP" 'BEGIN {
        FS=OFS="\t"; 
        while(getline < map > 0) vaf[$1]=$2 
    }
    /^#Uploaded_variation/ { print $0, "VAF_sample"; next }
    !/^#/ { print $0, (vaf[$1] ? vaf[$1] : "0") }' "$OUTPUT_TSV_RAW" > "$OUTPUT_TSV"

    rm "$PASS_VCF" "${PASS_VCF}.csi" "$VAF_MAP" "$OUTPUT_TSV_RAW"

done

MASTER_TSV="$OUTDIR/ALL_SAMPLES_master.tsv"
echo "[INFO] Vytvaram zlucenu tabulku: $MASTER_TSV" | tee -a "$LOG_FILE"

FIRST_TSV=$(find "$OUTDIR" -name "*_annotated.tsv" | head -n 1)

if [[ -n "$FIRST_TSV" ]]; then
    grep "^#Uploaded_variation" "$FIRST_TSV" | sed 's/^#//' | awk 'BEGIN{OFS="\t"} {print "Patient_ID", "Disease", $0}' > "$MASTER_TSV"

    for DISEASE_DIR in "$OUTDIR"/*/; do
        D_NAME=$(basename "$DISEASE_DIR")
        for TSV_FILE in "$DISEASE_DIR"/*_annotated.tsv; do
            [[ -e "$TSV_FILE" ]] || continue 
            P_NAME=$(basename "$TSV_FILE" _annotated.tsv)
            grep -v "^#" "$TSV_FILE" | awk -v p="$P_NAME" -v d="$D_NAME" 'BEGIN{FS=OFS="\t"} {print p, d, $0}' >> "$MASTER_TSV"
        done
    done
    echo "[INFO] Zlucovanie dokoncene." | tee -a "$LOG_FILE"
else
    echo "[WARN] Nenasli sa ziadne anotovane TSV subory na zlucenie." | tee -a "$LOG_FILE"
fi

echo "==================================================" | tee -a "$LOG_FILE"
echo "[INFO] Vsetci pacienti boli uspesne spracovani." | tee -a "$LOG_FILE"
