# BP_skripty

Repozitár pre bakalársku prácu: spracovanie NGS dát panelu **OncoZoom Cancer Hotspot**.

Aktuálne implementované kroky pipeline:
- **01** kontrola kvality vstupných FASTQ (`FastQC`, `MultiQC`)
- **02** orezávanie a filtrovanie čítaní (`fastp`, `MultiQC`)
- **03** mapovanie na referenčný genóm (`BWA-MEM`, `samtools`)
- **04** orezanie primerov po mapovaní (`samtools ampliconclip`)

Plánované rozšírenie:
- **05** kontrola pokrytia cieľových oblastí
- **06** variant calling a filtrácia

## Štruktúra repozitára

```text
BP_skripty/
├── config/
│   ├── params.env
│   └── samples.tsv
├── docs/
│   └── methodology.md
├── logs/
├── results/
│   ├── 01_qc/
│   ├── 02_fastp/
│   ├── 03_mapping/
│   └── 04_primer_trim/
├── scripts/
│   ├── 01_qc_fastqc_multiqc.sh
│   ├── 02_trim_filter_fastp.sh
│   ├── 03_map_bwa_samtools.sh
│   ├── 04_primer_trim_samtools.sh
│   └── run_pipeline.sh
└── README.md
```

## Požiadavky

- Linux alebo HPC cluster
- `fastqc`
- `multiqc`
- `fastp`
- `bwa`
- `samtools`

Poznámka: Na clustri je možné použiť `module load ...`; skripty sa pokúsia moduly načítať, ak je `module` dostupné.

### Príprava referenčného genómu
Skripty predpokladajú, že referenčný genóm (`REF_FASTA`) je vopred indexovaný pre `BWA` aj `GATK`. Ak indexy nemáte, vytvorte ich:

```bash
# BWA indexy
bwa index GRCh38.fa

# Samtools index
samtools faidx GRCh38.fa

# GATK/Picard dictionary
gatk CreateSequenceDictionary -R GRCh38.fa

## Quick start

1. Upravte `config/params.env` podľa vášho prostredia (vstupy, referencia, BED, vlákna).
2. Spustite pipeline kroky 01–04:

```bash
bash scripts/run_pipeline.sh --config config/params.env
```

## Samostatné spustenie krokov

### 01 QC

```bash
bash scripts/01_qc_fastqc_multiqc.sh \
	--indir data/raw_fastq \
	--outdir results/01_qc \
	--logdir logs
```

### 02 fastp

```bash
bash scripts/02_trim_filter_fastp.sh \
	--indir data/raw_fastq \
	--outdir results/02_fastp \
	--report-dir results/02_fastp \
	--threads 4 \
	--logdir logs
```

### 03 mapovanie

```bash
bash scripts/03_map_bwa_samtools.sh \
	--ref-fasta genomes/GRCh38/GRCh38.fa \
	--fastqdir results/02_fastp \
	--outdir results/03_mapping \
	--threads 8 \
	--logdir logs
```

### 04 orezanie primerov

```bash
bash scripts/04_primer_trim_samtools.sh \
	--indir results/03_mapping \
	--primer-bed config/primers.bed \
	--outdir results/04_primer_trim \
	--threads 4 \
	--logdir logs
```

## Reprodukovateľnosť

- Každý krok zapisuje log do `logs/`.
- Skripty kontrolujú povinné vstupy a dostupnosť nástrojov.
- Metodické odôvodnenie parametrov je v `docs/methodology.md`.
