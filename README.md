# BP_skripty

Repozitár pre bakalársku prácu: spracovanie NGS dát z panelového sekvenovania.

Aktuálne implementované kroky pipeline:
- **01** kontrola kvality vstupných FASTQ (`FastQC`, `MultiQC`)
- **02** orezávanie a filtrovanie čítaní (`fastp`, `MultiQC`)
- **03** mapovanie na referenčný genóm (`BWA-MEM`, `samtools`)
- **04** orezanie primerov po mapovaní (`samtools ampliconclip`)
- **05** kontrola pokrytia cieľových oblastí (`bedtools`)
- **06** somatický variant calling a filtrácia variantov (`gatk`)

## Štruktúra repozitára

```text
BP_skripty/
├── config/
│   ├── params.env              # Globálne nastavenia ciest a parametrov
│   └── samples.tsv             # Definícia vzoriek 
├── docs/
│   └── methodology.md          # Detailný popis použitej bioinformatickej metodiky
├── logs/                       # Logovacie súbory jednotlivých behov pipeline
├── results/                    # Výstupné dáta organizované podľa krokov
│   ├── 01_qc/                  # Raw FastQC a MultiQC reporty
│   ├── 02_fastp/               # Orezané a filtrované FASTQ súbory
│   ├── 03_mapping/             # Namapované BAM súbory (sorted)
│   ├── 04_primer_trim/         # BAM súbory po odstránení primerov (trimmed)
│   └── 05_coverage/            # Metriky pokrytia cielových oblastí (bedtools)
├── scripts/
│   ├── 01_qc_fastqc_multiqc.sh # Kontrola kvality surových dát
│   ├── 02_trim_filter_fastp.sh # Filtering a trimming (fastp)
│   ├── 03_map_bwa_samtools.sh  # Mapovanie na referenciu (BWA MEM)
│   ├── 04_primer_trim_samtools.sh # Odstránenie primerov z amplikónov (samtools)
│   ├── 05_coverage_metrics.sh  # Výpočet hĺbky pokrytia panelu (bedtools)
│   ├── 06_variant_calling_mutect2.sh  # Volanie variantov a ich filtrácia (gatk)
│   └── run_pipeline.sh         # Hlavný riadiaci skript (Master script)
└── README.md                   # Dokumentácia k repozitáru
```

## Požiadavky

- Linux alebo HPC cluster
- `fastqc`
- `multiqc`
- `fastp`
- `bwa`
- `samtools`
- `bedtools`
- `gatk`

### Príprava referenčného genómu
Skripty predpokladajú, že referenčný genóm (`REF_FASTA`) je vopred indexovaný pre `BWA` aj `GATK` a indexy sú uložené v rovnakom priečinku ako referenčný genóm. Ak indexy nemáte, vytvorte ich:

```bash
# BWA indexy
bwa index GRCh38.fa

# Samtools index
samtools faidx GRCh38.fa

# GATK/Picard dictionary
gatk CreateSequenceDictionary -R GRCh38.fa
```
### Príprava panelu normálnych vzoriek
Táto pipeline predpokladá použitie Panel  of Normals (PoN) na potlačenie technického šumu a artefaktov. Ak si potrebujete vygenerovať vlastný panel z kontrolných vzoriek, môžete postupovať podľa oficiálneho návodu v GATK dokumentácii (https://gatk.broadinstitute.org/hc/en-us/articles/360036348732-CreateSomaticPanelOfNormals-BETA). Odporúča sa použiť aspoň 20 normálnych vzoriek spracovaných rovnakou technológiou a v rovnakom laboratóriu ako vaše vzorky.

## Quick start

1. Upravte `config/params.env` podľa vášho prostredia (vstupy, referencia, PoN, BED, vlákna).
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
### 05 kontrola pokrytia cieľových oblastí

```bash
bash scripts/05_coverage_metrics.sh \
	--indir results/04_primer_trim \
	--bed path/to/ampInsert.bed \
	--outdir results/05_coverage \
	--threads 1 \
	--logdir logs
```

### 06 somatický variant calling

```bash
bash scripts/06_variant_calling_mutect2.sh \
    --indir results/04_primer_trim \
    --tsv config/samples.tsv \
    --ref path/to/GRCh38.fa \
    --bed path/to/ampInsert.bed \
    --pon path/to/pon.vcf.gz \
    --gnomad path/to/af-only-gnomad.vcf.gz \
    --outdir results/06_variant_calling \
    --threads 4 \
    --logdir logs
```

## Reprodukovateľnosť

- Každý krok zapisuje log do `logs/`.
- Skripty kontrolujú povinné vstupy a dostupnosť nástrojov.
- Metodické odôvodnenie parametrov je v `docs/methodology.md`.
