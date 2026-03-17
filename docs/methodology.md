# Methodology Notes (Bachelor Thesis)

## Data processing workflow
1. **Raw read QC**: `FastQC` + `MultiQC`
2. **Read trimming/filtering**: `fastp`
3. **Reference mapping**: `BWA-MEM`
4. **Primer trimming after mapping**: `samtools ampliconclip`

## Key parameter rationale
- **Quality trimming**: tail trimming with threshold `Q30`.
- **Average read quality**: minimum `Q30` to reduce low-quality noise.
- **Minimum read length**: `30 bp` after trimming.
- **Adapters**: explicit R1/R2 adapter sequences from assay specification.
- **Read groups**: set per-sample (`ID`, `SM`, `PL`, `LB`) for downstream compatibility.

## Reproducibility
- All scripts log command outputs and tool versions into `logs/`.
- Paths and resource settings are centralized in `config/params.env`.
- Results are partitioned by pipeline step under `results/`.

