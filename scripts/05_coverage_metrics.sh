#!/bin/bash -l

# ========================================================
# Skript na vypocet pokrytia cielovych oblasti (bedtools)
# ========================================================

set -euo pipefail

usage() {
    cat <<EOF
Pouzitie:
  $(basename "$0") --indir <path> --bed <path> --outdir <path> [--logdir <path>]

Parametre:
  --indir   Priecinok so vstupnymi *.trimmed.bam subormi
  --bed     BED subor s cielovymi oblastami (PANEL_BED)
  --outdir  Vystupny priecinok pre metriky a tabulky
  --logdir  Priecinok s logmi (default: logs)
  --help    Zobrazi tuto napovedu
  --threads   Pocet vlakien (poznamka: bedtools coverage je single-threaded, ale parameter zachovavame kvoli konzistencii)
EOF
}

INDIR=""
BEDFILE=""
OUTDIR=""
THREADS=1
LOGDIR="logs"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --indir) INDIR="$2"; shift 2 ;;
        --bed) BEDFILE="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
	--threads) THREADS="$2"; shift 2 ;;
        --logdir) LOGDIR="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Neznamy parameter: $1"; usage; exit 1 ;;
    esac
done

# Kontrola povinnych parametrov
if [[ -z "$INDIR" || -z "$BEDFILE" || -z "$OUTDIR" ]]; then
    echo "Chyba: --indir, --bed a --outdir su povinne."
    usage
    exit 1
fi

# Overenie existencie vstupov
if [[ ! -d "$INDIR" ]]; then echo "Chyba: Vstupny priecinok neexistuje: $INDIR"; exit 1; fi
if [[ ! -f "$BEDFILE" ]]; then echo "Chyba: BED subor neexistuje: $BEDFILE"; exit 1; fi

# Nacitanie modulov (MetaCentrum poistka)
if [[ "$(type -t module || true)" != "" ]]; then
    module load bedtools || true
fi

if ! command -v bedtools >/dev/null 2>&1; then
    echo "Chyba: bedtools nie je dostupny. Skontroluj moduly."
    exit 1
fi

mkdir -p "$OUTDIR" "$LOGDIR"

# Vyhladanie BAM suborov
mapfile -t BAM_FILES < <(find "$INDIR" -maxdepth 1 -type f -name "*.trimmed.bam" | sort)
if [[ ${#BAM_FILES[@]} -eq 0 ]]; then
    echo "Chyba: V $INDIR neboli najdene subory *.trimmed.bam."
    exit 1
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)_05_coverage"
LOG_FILE="$LOGDIR/${RUN_ID}.log"

{
    echo "[INFO] Spustenie Coverage Metrics: $(date --iso-8601=seconds)"
    echo "[INFO] INDIR: $INDIR"
    echo "[INFO] BED: $BEDFILE"
    echo "[INFO] OUTDIR: $OUTDIR"
    echo "[INFO] THREADS: $THREADS"
    echo "[INFO] bedtools version: $(bedtools --version)"
} | tee "$LOG_FILE"

# Hlavna sumarna tabulka
SUMMARY_FILE="$OUTDIR/coverage_summary.tsv"
echo -e "sample\tmean_coverage\tpct_>=100x\tpct_>=500x\tpct_>=1000x" > "$SUMMARY_FILE"

for bam in "${BAM_FILES[@]}"; do
    base=$(basename "$bam" .trimmed.bam)
    perbase_file="$OUTDIR/${base}_perbase.tsv"

    echo "[$(date +%T)] Spracovavam vzorku: $base" | tee -a "$LOG_FILE"

    # 1. bedtools coverage (prepínač -d vypíše hĺbku pre každú bázu v BED intervaloch)
    bedtools coverage -a "$BEDFILE" -b "$bam" -d > "$perbase_file" 2>> "$LOG_FILE"

    # 2. Vypocet statistik pomocou AWK
    awk '
    {
        depth=$NF
        total++
        sum+=depth
        if(depth>=100)  c100++
        if(depth>=500)  c500++
        if(depth>=1000) c1000++
    }
    END {
        if(total > 0) {
            mean  = sum/total
            p100  = (c100/total)*100
            p500  = (c500/total)*100
            p1000 = (c1000/total)*100
        } else {
            mean=0; p100=0; p500=0; p1000=0
        }
        printf "%.2f\t%.2f\t%.2f\t%.2f\n", mean, p100, p500, p1000
    }' "$perbase_file" | \
    awk -v s="$base" 'BEGIN{OFS="\t"} {print s,$0}' >> "$SUMMARY_FILE"

    # Volitelne: Odstranenie perbase suboru kvoli setreniu miesta (byvaju velke)
    # rm -f "$perbase_file"
done

echo "[INFO] Hotovo. Sumarna tabulka: $SUMMARY_FILE" | tee -a "$LOG_FILE"

# Upratanie
module unload bedtools || true
