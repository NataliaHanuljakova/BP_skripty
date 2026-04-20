#!/bin/bash -l

# ===================================================================
# Skript pre Variant Annotation (VEP)
# Filtruje varianty a anotuje ich pomocou Ensembl VEP
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
        *) echo "[ERROR] Neznamy parameter: $1"; exit 1 ;;
    esac
done

if [[ -z "$INDIR" || -z "$TSV" || -z "$VEP_SIF" || -z "$VEP_CACHE" || -z "$REF" || -z "$OUTDIR" ]]; then
    echo "[ERROR] Chybaju povinne parametre."
    usage
    exit 1
fi

mkdir -p "$OUTDIR" "$LOGDIR"
RUN_ID="$(date +%Y%m%d_%H%M%S)_07_vep_annotation"
LOG_FILE="$LOGDIR/${RUN_ID}.log"

module load bcftools 2>/dev/null || true

command -v bcftools >/dev/null || { echo "[ERROR] bcftools chyba"; exit 1; }
command -v singularity >/dev/null || { echo "[ERROR] singularity chyba"; exit 1; }

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
        echo "[WARN] Missing VCF: $INPUT_VCF" | tee -a "$LOG_FILE"
        continue
    fi

    echo "[INFO] Processing $PATIENT_ID ($DISEASE)" | tee -a "$LOG_FILE"

    ALL_VCF="$PATIENT_OUTDIR/${PATIENT_ID}_all.vcf.gz"
    bcftools annotate --set-id '%CHROM\_%POS\_%REF\_%ALT' "$INPUT_VCF" -O z -o "$ALL_VCF"
    bcftools index -f "$ALL_VCF"

    VARIANT_COUNT=$(bcftools view -H "$ALL_VCF" | wc -l || echo 0)
    echo "[INFO] Variant count: $VARIANT_COUNT" | tee -a "$LOG_FILE"

    if [[ "$VARIANT_COUNT" -eq 0 ]]; then
        echo "[WARN] No variants for $PATIENT_ID" | tee -a "$LOG_FILE"
        continue
    fi

    ACTUAL_SAMPLE=$(bcftools query -l "$ALL_VCF" | grep -i "${PATIENT_ID}" | head -n 1 || true)
    if [[ -z "$ACTUAL_SAMPLE" ]]; then
        ACTUAL_SAMPLE=$(bcftools query -l "$ALL_VCF" | head -n 1)
    fi

    echo "[INFO] Extrakcia VAF pre vzorku: $ACTUAL_SAMPLE" | tee -a "$LOG_FILE"

    MAP_FILE="$PATIENT_OUTDIR/${PATIENT_ID}_info.map"
    bcftools query -f "%ID\t%FILTER\t[%AF]\t[%AD]\n" -s "$ACTUAL_SAMPLE" "$ALL_VCF" | \
    awk 'BEGIN{OFS="\t"} {
        id = $1; filter = $2; af = $3; ad = $4;
        vaf = "NA";
        
        # Rozdelenie podla ciarky (ak by VCF obsahovalo multialelicke pozicie)
        split(af, afs, ",");
        split(ad, ads, ",");
        
        # Priorita 1: Ak vo VCF existuje priamo hodnota AF (napr. tvojich 0.165), zoberieme ju
        if (afs[1] != "" && afs[1] != ".") {
            vaf = afs[1];
        } 
        # Priorita 2: Ak AF chyba, skusime ho doratat z AD (ALT / (REF + ALT))
        else if (ads[1] != "" && ads[1] != "." && ads[2] != "" && ads[2] != ".") {
            if ((ads[1] + ads[2]) > 0) {
                vaf = ads[2] / (ads[1] + ads[2]);
            }
        }
        
        # Ulozime vysledok s pevnym ID
        print id, filter, vaf;
    }' > "$MAP_FILE"

    OUTPUT_RAW="$PATIENT_OUTDIR/${PATIENT_ID}_annotated_raw.tsv"

    REF_DIR=$(dirname "$REF")
    BIND_PATHS="$INDIR,$OUTDIR,$VEP_CACHE,$REF_DIR,/storage"

    singularity exec -B "$BIND_PATHS" "$VEP_SIF" vep \
        --dir_cache "$VEP_CACHE" \
        --fasta "$REF" \
        --input_file "$ALL_VCF" \
        --output_file "$OUTPUT_RAW" \
        --cache --offline --assembly GRCh38 --species homo_sapiens \
        --everything --tab --force_overwrite --no_stats \
        --flag_pick \
        --fork "$THREADS" 2>> "$LOG_FILE"

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
        f = (filter[$1] != "" ? filter[$1] : ".");
        v = (vaf[$1] != "" ? vaf[$1] : "NA");

        if (v == "NA") {
            print "[WARN] missing VAF for " $1 > "/dev/stderr"
        }

        print $0, f, v
    }' "$OUTPUT_RAW" > "$OUTPUT_TSV"

done

# ============================
# MASTER TABLE
# ============================
MASTER_TSV="$OUTDIR/ALL_SAMPLES_master.tsv"
echo "============================" | tee -a "$LOG_FILE"
echo "[INFO] Creating master table" | tee -a "$LOG_FILE"

FIRST_TSV=$(find "$OUTDIR" -name "*_annotated.tsv" | head -n 1 || true)

if [[ -n "$FIRST_TSV" && -f "$FIRST_TSV" ]]; then

    HEADER=$(grep "^#Uploaded_variation" "$FIRST_TSV" | sed 's/^#//' || true)

    if [[ -n "$HEADER" ]]; then
        echo -e "Patient_ID\tDisease\t$HEADER" > "$MASTER_TSV"
    else
        echo "[ERROR] Header not found in $FIRST_TSV" | tee -a "$LOG_FILE"
        exit 1
    fi

    for DISEASE_DIR in "$OUTDIR"/*/; do
        # Osetrenie, ak by zlozka s chorobou neexistovala (len * wildcard)
        [[ -d "$DISEASE_DIR" ]] || continue 
        
        D_NAME=$(basename "$DISEASE_DIR")

        for TSV_FILE in "$DISEASE_DIR"/*_annotated.tsv; do
            [[ -e "$TSV_FILE" ]] || continue

            P_NAME=$(basename "$TSV_FILE" _annotated.tsv)

            # Cisty awk prikaz bez problemoveho 'grep |' ktory pri prazdnych suboroch padal kvoli set -e
            awk -v p="$P_NAME" -v d="$D_NAME" 'BEGIN{FS=OFS="\t"} !/^#/ {print p, d, $0}' "$TSV_FILE" >> "$MASTER_TSV"
   
        done
    done

    echo "[INFO] Master table OK: $MASTER_TSV" | tee -a "$LOG_FILE"
else
    echo "[WARN] No TSV files found for master table" | tee -a "$LOG_FILE"
fi

echo "[INFO] Finished: $(date)" | tee -a "$LOG_FILE"
