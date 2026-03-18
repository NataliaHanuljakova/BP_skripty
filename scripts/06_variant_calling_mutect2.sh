#!/bin/bash -l

# ===================================================================
# Skript pre Somatic Variant Calling (GATK Mutect2)
# Podporuje: Tumor-only, 1T:1N, nT:1N
# Triedi vystupy do priecinkov podla 'disease' stlpca v samples.tsv
# ===================================================================

set -euo pipefail

usage() {
    cat <<EOF
Pouzitie:
  $(basename "$0") 
	--indir <path> 
	--tsv <samples.tsv> 
	--ref <path> --bed <path> 
	--pon <path> 
	--gnomad <path> 
	--outdir <path>
	[--threads <n>] 
	[--logdir <path>]
EOF
}

# Inicializacia
INDIR=""; TSV=""; REF=""; BED=""; PON=""; GNOMAD=""; OUTDIR=""; THREADS=4; LOGDIR="logs"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --indir) INDIR="$2"; shift 2 ;;
        --tsv) TSV="$2"; shift 2 ;;
        --ref) REF="$2"; shift 2 ;;
        --bed) BED="$2"; shift 2 ;;
        --pon) PON="$2"; shift 2 ;;
        --gnomad) GNOMAD="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
	--threads) THREADS="$2"; shift 2 ;;
        --logdir) LOGDIR="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Neznamy parameter: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "$INDIR" || -z "$TSV" || -z "$OUTDIR" ]]; then
    echo "Chyba: Chybaju povinne parametre. Spusti s --help"
    exit 1
fi

mkdir -p "$OUTDIR" "$LOGDIR"
RUN_ID="$(date +%Y%m%d_%H%M%S)_06_mutect2"
LOG_FILE="$LOGDIR/${RUN_ID}.log"
TMP_DIR="${SCRATCHDIR:-/tmp}"

if [[ "$(type -t module || true)" != "" ]]; then
    module load gatk || true
fi

if ! command -v gatk >/dev/null 2>&1; then
    echo "Chyba: GATK nie je dostupny." | tee -a "$LOG_FILE"
    exit 1
fi

{
    echo "[INFO] Spustenie Variant Calling: $(date --iso-8601=seconds)"
    echo "[INFO] TSV Tabulka: $TSV"
    echo "[INFO] Hlavny vystupny priecinok: $OUTDIR"
    echo "[INFO] Vlakna (PairHMM): $THREADS"
} | tee "$LOG_FILE"

# 1. Ziskanie unikatnych pacientov z TSV (vynechame hlavicku)
PATIENTS=$(awk 'NR>1 {print $1}' "$TSV" | sort -u)

for PATIENT_ID in $PATIENTS; do
    echo "==================================================" | tee -a "$LOG_FILE"
    
    # Zistenie ochorenia (disease) pre tohto pacienta (zo 4. stlpca)
    # Berieme prvy riadok, ktory patri pacientovi
    DISEASE=$(awk -v p="$PATIENT_ID" '$1==p {print $4}' "$TSV" | head -n 1)
    
    # Poistka, ak by v tabulke chybala hodnota
    if [[ -z "$DISEASE" ]]; then
        DISEASE="Unknown"
    fi
    
    # Vytvorenie dynamickeho priecinka pre dane ochorenie
    PATIENT_OUTDIR="$OUTDIR/$DISEASE"
    mkdir -p "$PATIENT_OUTDIR"

    echo "[INFO] Pacient: $PATIENT_ID | Diagnoza: $DISEASE | Vystup: $PATIENT_OUTDIR" | tee -a "$LOG_FILE"
    
    # 2. Extrahovanie vzoriek pre daneho pacienta
    TUMOR_SAMPLES=$(awk -v p="$PATIENT_ID" '$1==p && $3=="tumor" {print $2}' "$TSV")
    NORMAL_SAMPLES=$(awk -v p="$PATIENT_ID" '$1==p && $3=="normal" {print $2}' "$TSV")
    NORMAL_ID=$(echo "$NORMAL_SAMPLES" | head -n 1)

    if [[ -z "$TUMOR_SAMPLES" ]]; then
        echo "[WARN] Ziadny tumor pre pacienta $PATIENT_ID. Preskakujem." | tee -a "$LOG_FILE"
        continue
    fi

    # 3. Priprava argumentov pre Mutect2
    M2_ARGS=""
    ALL_SAMPLES=""

    for TUMOR_ID in $TUMOR_SAMPLES; do
        T_BAM="$INDIR/${TUMOR_ID}.trimmed.bam"
        if [[ ! -f "$T_BAM" ]]; then echo "Chyba: Nenasiel sa BAM $T_BAM"; exit 1; fi
        M2_ARGS="$M2_ARGS -I $T_BAM"
        ALL_SAMPLES="$ALL_SAMPLES $TUMOR_ID"
    done

    if [[ -n "$NORMAL_ID" ]]; then
        N_BAM="$INDIR/${NORMAL_ID}.trimmed.bam"
        if [[ ! -f "$N_BAM" ]]; then echo "Chyba: Nenasiel sa Normal BAM $N_BAM"; exit 1; fi
        M2_ARGS="$M2_ARGS -I $N_BAM -normal $NORMAL_ID"
        ALL_SAMPLES="$ALL_SAMPLES $NORMAL_ID"
        echo "[INFO] Rezim: Matched Normal (N: $NORMAL_ID, T: $(echo $TUMOR_SAMPLES))" | tee -a "$LOG_FILE"
    else
        echo "[INFO] Rezim: Tumor-Only (T: $(echo $TUMOR_SAMPLES))" | tee -a "$LOG_FILE"
    fi

    # --------------------------------------------------
    # KROK A: Mutect2
    # --------------------------------------------------
    gatk Mutect2 \
        -R "$REF" \
        $M2_ARGS \
        -L "$BED" \
        --panel-of-normals "$PON" \
        --germline-resource "$GNOMAD" \
	--native-pair-hmm-threads "$THREADS" \
        -O "$PATIENT_OUTDIR/${PATIENT_ID}_mutect2.vcf.gz" \
        --f1r2-tar-gz "$PATIENT_OUTDIR/${PATIENT_ID}_f1r2.tar.gz" \
        --tmp-dir "$TMP_DIR" 2>> "$LOG_FILE"

    # --------------------------------------------------
    # KROK B: GetPileupSummaries
    # --------------------------------------------------
    for SM_ID in $ALL_SAMPLES; do
        gatk GetPileupSummaries \
            -I "$INDIR/${SM_ID}.trimmed.bam" \
            -V "$GNOMAD" \
            -L "$BED" \
            -O "$PATIENT_OUTDIR/${SM_ID}_pileups.table" \
            --tmp-dir "$TMP_DIR" 2>> "$LOG_FILE"
    done

    # --------------------------------------------------
    # KROK C: CalculateContamination
    # --------------------------------------------------
    FIRST_TUMOR_ID=$(echo $TUMOR_SAMPLES | awk '{print $1}')
    CONTAM_ARGS="-I $PATIENT_OUTDIR/${FIRST_TUMOR_ID}_pileups.table"

    if [[ -n "$NORMAL_ID" ]]; then
        CONTAM_ARGS="$CONTAM_ARGS -matched $PATIENT_OUTDIR/${NORMAL_ID}_pileups.table"
    fi

    gatk CalculateContamination \
        $CONTAM_ARGS \
        -O "$PATIENT_OUTDIR/${PATIENT_ID}_contamination.table" \
        --tumor-segmentation "$PATIENT_OUTDIR/${PATIENT_ID}_segments.table" \
        --tmp-dir "$TMP_DIR" 2>> "$LOG_FILE"

    # --------------------------------------------------
    # KROK D: LearnReadOrientationModel
    # --------------------------------------------------
    gatk LearnReadOrientationModel \
        -I "$PATIENT_OUTDIR/${PATIENT_ID}_f1r2.tar.gz" \
        -O "$PATIENT_OUTDIR/${PATIENT_ID}_read-orientation-model.tar.gz" \
        --tmp-dir "$TMP_DIR" 2>> "$LOG_FILE"

    MODEL_PATH="$PATIENT_OUTDIR/${PATIENT_ID}_read-orientation-model.tar.gz"
    FILE_SIZE=$(stat -c%s "$MODEL_PATH" 2>/dev/null || echo 0)
    
    # --------------------------------------------------
    # KROK E: FilterMutectCalls
    # --------------------------------------------------
    gatk FilterMutectCalls \
        -V "$PATIENT_OUTDIR/${PATIENT_ID}_mutect2.vcf.gz" \
        -R "$REF" \
        --contamination-table "$PATIENT_OUTDIR/${PATIENT_ID}_contamination.table" \
        --tumor-segmentation "$PATIENT_OUTDIR/${PATIENT_ID}_segments.table" \
        --ob-priors $MODEL_PATH \
        -O "$PATIENT_OUTDIR/${PATIENT_ID}_filtered.vcf.gz" \
        --tmp-dir "$TMP_DIR" 2>> "$LOG_FILE"

    echo "[INFO] Pacient $PATIENT_ID uspesne dokonceny." | tee -a "$LOG_FILE"
done

echo "==================================================" | tee -a "$LOG_FILE"
echo "[INFO] Vsetci pacienti boli uspesne spracovani." | tee -a "$LOG_FILE"