# BP_skripty

Tento repozitár obsahuje skripty na spracovanie dát z panelu OncoZoom Cancer Hotspot.
Vykonáva tieto kroky:
- **01** - kontrola kvality vstupných FASTQ súborov (FastQC, MultiQC)
- **02** - orezávanie a filtrovanie čítaní a následné zhrnutie tohto procesu (fastp, MultiQC)
- **03** - mapovanie na referenčný genóm (BWA-MEM, Samtools)
- **04** - orezanie primerov po mapovaní (Samtools)
- **05** - kontrola pokrytia cieľových oblastí
- **06** - variant calling

## Požiadavky

- Linux alebo cluster s PBS

## Použitie

- **01 - kontrola kvality vstupných FASTQ súborov (FastQC, MultiQC):**
```bash
bash 01_kontrola_kvality.sh
```

- **02 - orezávanie a filtrovanie čítaní a následné zhrnutie výsledkov tohto procesu (fastp, MultiQC):**
```
bash 02_orezavanie_filtrovanie.sh
```
