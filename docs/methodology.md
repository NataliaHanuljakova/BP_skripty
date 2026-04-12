---
bibliography: references.bib
---

# Metódy

## Vstupné súbory 

Vstupom do tejto analýzy boli súbory vo formáte FASTQ, ktoré vznikajú v procese *base callingu*. Každé čítanie vo FASTQ súbore je uložené v štandardizovanej 4-riadkovej štruktúre. Tá zahŕňa identifikátor čítania, samotnú sekvenciu a informáciu o kvalite jednotlivých báz. Kvalita je reprezentovaná pomocou Phred skóre, kde vyššia hodnota znamená vyššiu spoľahlivosť určenia bázy. Konverzia medzi kvalitou vyjadrenou pomocou Phred skóre (Q) a pravdepodobnosťou chybne určenej bázy (P) sa riadi vzorcami:

$$Q = -10 \times \log_{10}(P)$$

$$P = 10^{-\frac{Q}{10}}.$$
 
Phred skóre sa vo FASTQ súboroch nezapisuje v číselnej podobe, ale je prekódované do ASCII znakov (Cock et al. 2009-12-16). Na moderných Illumina systémoch, vrátane Illumina NextSeq, sa používa offset 33 (Phred+33), a teda platí

$$\text{kód ASCII znaku} = \text{Phred skóre} + 33.$$

Pri *paired-end* sekvenovaní sa pre každú vzorku vytvoria dva samostatné FASTQ súbory. Obsahujú čítania získané z opačných koncov tých istých fragmentov (Larson et al. 2023).

## Kontrola kvality dát

Prvým krokom bioinformatického spracovania je prvotná kontrola kvality dát. Jej cieľom je získať lepší prehľad o datasete a identifikovať možné problémy. Zároveň slúži ako referencia pred úpravami dát.

### Nástroj FastQC

FastQC je voľne dostupný bioinformatický nástroj určený na kontrolu kvality sekvenačných dát. Využíva sa na identifikáciu potenciálnych problémov, ktoré môžu vzniknúť počas sekvenovania alebo pri príprave knižnice. Vstupom bývajú FASTQ súbory alebo SAM a BAM súbory. Výstupom je prehľadná správa vo formáte HTML a ZIP priečinok s rovnakými výsledkami, no v surovej forme.

FastQC využíva viacero analytických modulov, ktoré vyhodnocujú rôzne aspekty dát. Medzi najpoužívanejšie moduly patria:

- *Basic Statistics*, ktorý vypíše základné štatistiky analyzovaného súboru: názov a typ súboru, ktoré ASCII kódovanie kvality bolo využité, celkový počet čítaní v súbore, dĺžku najkratšieho a najdlhšieho čítania, percentuálny obsah GC báz a prípadne aj ďalšie štatistiky.

- *Per Base Sequence Quality*, ktorý zobrazuje rozdelenie kvality báz na jednotlivých pozíciách v čítaniach. Kvalita je vyjadrená pomocou Phred skóre a zohľadňujú sa všetky čítania v súbore.

- *Per Base Sequence Content*, ktorý zobrazuje podiel adenínu, cytozínu, guanínu a tymínu na jednotlivých pozíciách v čítaniach.

- *Adapter Content*, ktorý zobrazuje kumulatívny podiel čítaní v súbore, ktoré obsahujú adaptérové sekvencie pre každú pozíciu.

- *Per Sequence GC Content*, ktorý znázorňuje rozdelenie priemerného obsahu GC báz v čítaniach a porovnáva ho s modelovaným normálnym rozdelením (Andrews 2010).

### Nástroj MultiQC

MultiQC je voľne dostupný nástroj, ktorý spracováva výsledky z rôznych bioinformatických nástrojov a tvorí súhrnné reporty. Množstvo bioinformatických nástrojov generuje výstupy pre každú vzorku samostatne. V prípade rozsiahlych datasetov je manuálne vyhodnocovanie individuálnych výstupov neefektívne a náchylné na chyby. MultiQC výrazne urýchľuje proces kontroly kvality aj následnej analýzy dát tým, že tieto výstupy automaticky vyhľadáva a integruje do jediného reportu (Ewels et al. 2016-6-16).

V súčasnosti MultiQC podporuje až 168 rôznych bioinformatických nástrojov a prijíma širokú škálu vstupných formátov. Vstupom bývajú najmä textové a logové súbory, ale napríklad aj HTML a ZIP súbory vygenerované pomocou FastQC. Výstup tvorí sumárna správa vo formáte HTML a priečinok s parsovanými dátami so štandardizovanou štruktúrou (Labs 2025).

## Predspracovanie dát

Predspracovanie je neoddeliteľnou súčasťou každej práce so sekvenačnými dátami. Jeho podstatou je získať čo najčistejšie a najspoľahlivejšie čítania, čím sa zvyšuje presnosť následnej analýzy (Cabello-Aguilar et al. 2023). Typickými krokmi predspracovania bývajú orezávanie (angl. *trimming*), filtrovanie, mapovanie na referenčný genóm a deduplikácia čítaní.

### Orezávanie a filtrovanie

V procese orezávania sa zbavujeme nežiaducich častí čítaní. Napríklad zvyškov adaptérových sekvencií, polyG koncov či nízkokvalitných báz na koncoch čítaní (Cabello-Aguilar et al. 2023). Filtrovanie zas slúži na odstránenie celých čítaní, ktoré nespĺňajú stanovené kritériá. Napríklad majú nedostatočnú dĺžku alebo nízku priemernú kvalitu báz. Obe tieto operácie, orezávanie aj filtrovanie, je možné vykonať pomocou voľne dostupného nástroja fastp (Chen et al. 2018).

Nástroj fastp umožňuje efektívne predspracovanie FASTQ súborov. Vrátane kontroly kvality, odstránenia adaptérov, filtrovania či orezávania čítaní na základe kvality jednotlivých báz. Umožňuje tiež deduplikáciu alebo spracovanie unikátnych molekulárnych identifikátorov (UMI). Tieto operácie vykonáva v rámci jediného prechodu dátami. Vďaka tomu je výrazne rýchlejší než ďalšie voľne dostupné nástroje ako napríklad Trimmomatic či Cutadapt. Výhodou fastp je tiež možnosť automatickej detekcie adaptérov (Chen et al. 2018).

### Mapovanie na referenčný genóm

Po orezávaní a filtrovaní sa upravené čítania mapujú na referenčný genóm. Tento krok spočíva v identifikovaní najpravdepodobnejšej pozície jednotlivých čítaní v genóme. Zarovnávacie algoritmy pritom zohľadňujú možnú genetickú variabilitu a chyby sekvenovania (Larson et al. 2023).

*Paired-end* čítania sú zarovnávané súčasne a umožňujú presnejšie určenie ich polohy a orientácie v genóme. Informácia o vzdialenosti a smere medzi párovanými čítaniami zvyšuje spoľahlivosť mapovania najmä v repetitívnych alebo komplexných oblastiach genómu.

K mapovaniu je možné využiť softvérový balík BWA. Slúži na zarovnanie málo divergentných sekvencií na veľký referenčný genóm, akým je aj ľudský genóm. Využíva Burrows-Wheelerovu transformáciu a FM-index (z angl. *Full-text Minute-space index*) referenčného genómu. Práve tie umožňujú efektívne vyhľadávanie zhodných úsekov v referenčnej sekvencii. FM-index referenčného genómu je možný pripraviť priamo pomocou príkazu v balíku BWA `bwa index`.

Balík zahŕňa tri algoritmy: BWA-backtrack, BWA-SW a BWA-MEM. BWA-backtrack bol navrhnutý pre krátke Illumina čítania do 100 bp. BWA-SW a BWA-MEM zas slúžia na mapovanie dlhších sekvencií v rozsahu od 70 bp do 1 Mbp. Pre túto analýzu bol využitý novší algoritmus BWA-MEM kvôli svojej vyššej presnosti a schopnosti efektívne pracovať s *paired-end* čítaniami.

BWA-MEM pri zarovnávaní používa tiež mechanizmus známy ako *clipping*, ktorý umožňuje dočasne (*soft-clipping*) alebo trvalo (*hard-clipping*) orezať bázy čítania, ktoré nesedia na referenciu. Výstupom z mapovania sú súbory vo formáte SAM (Li 2013), ktoré sú podrobne popísané v nasledujúcej sekcii.

#### Súbory vo formáte SAM

Výstupy z mapovania sa štandardne ukladajú vo formáte SAM (z angl. *Sequence Alignment/Map*). Súbory SAM pozostávajú z dvoch sekcií: hlavičky a samotného alignmentu, pričom údaje v jednotlivých riadkoch sú oddelené tabulátorom.

Riadky hlavičky sa začínajú znakom `"@"` a obsahujú informácie o referenčnom genóme, použitých nástrojoch a spôsobe spracovania. V sekcii alignmentu je každé mapované čítanie uložené ako jeden riadok s 11 povinnými a prípadne aj ďalšími voliteľnými poliami. Medzi povinné polia patria:

- `QNAME`, ktoré obsahuje identifikátor zarovnaného čítania.

- `FLAG` obsahuje celé číslo reprezentujúce bitovú masku. Tá kóduje informácie napríklad o tom, či je čítanie zarovnané, duplicitné, párové.

- `RNAME` určuje názov referenčnej sekvencie, na ktorú bolo čítanie zarovnané.

- `POS` udáva pozíciu, kde sa čítanie začína na referencii, čiže ľavý okraj zarovnania.

- `MAPQ` predstavuje spoľahlivosť zarovnania daného čítania na referenciu. Spoľahlivosť je vyjadrená nasledujúcim vzorcom: $$MAPQ = -10 \times \log_{10}(P),$$ kde P je pravdepodobnosť nesprávneho zarovnania. Táto hodnota je zaokrúhlená na najbližšie celé číslo. Hodnota 255 indikuje, že spoľahlivosť zarovnania nie je dostupná.

- `CIGAR` obsahuje reťazec, ktorý popisuje presný tvar zarovnania čítania na referenciu, vrátane zhôd s referenciou, inzertovaných a deletovaných báz alebo báz orezaných (angl. *clipped*).

- `RNEXT` obsahuje názov referenčnej sekvencie párového čítania. Znak ` =` znamená, že sa `RNEXT` zhoduje s `RNAME`.

- `PNEXT` udáva pozíciu párového čítania na referencii.

- `TLEN` udáva pozorovanú veľkosť insertu, ktorý prislúcha k daným párovým čítaniam. Znamienka `"+"` a ` -` určujú orientáciu daného čítania.

- `SEQ` obsahuje nukleotidovú sekvenciu zarovnaného čítania. Bázy orezané pri *hard-clipping* sú z tejto sekvencie vynechané.

- `QUAL` obsahuje Phred skóre jednotlivých báz v sekvencii prekódované do ASCII znakov.

Chýbajúce informácie sú nahradené znakom `"@"` alebo `"0"` podľa typu poľa (SAM/BAM Format Specification Working Group 2024).

SAM súbory je možné konvertovať do svojej komprimovanej binárnej podoby BAM. Výhodou BAM súborov je ich menšia veľkosť a možnosť indexovania napríklad pomocou balíku Samtools (Danecek et al. 2021). Indexovaný BAM súbor (súbor .bai) potom umožňuje rýchly prístup ku konkrétnym oblastiam genómu bez nutnosti načítania celého súboru.

Ďalšou komprimovanou formou SAM je aj CRAM formát. Ukladá iba rozdiely medzi čítaniami a referenciou, čím dosahuje výraznejšiu úsporu miesta. Niektoré CRAM súbory však využívajú stratovú kompresiu, a preto nemusia umožňovať úplnú rekonštrukciu pôvodných BAM dát (Larson et al. 2023).

### Deduplikácia

Ďalším krokom bioinformatickej analýzy je deduplikácia. Jej cieľom je identifikovať a odstrániť duplicitné čítania, kedy je sekvenovaných viacero kópií toho istého pôvodného fragmentu DNA. Počas amplifikácie v polymerázovej reťazovej reakcii (PCR, z angl. *Polymerase Chain Reaction*) totiž vzniká veľké množstvo identických fragmentov z jednej pôvodnej molekuly. Duplicitné čítania vznikajú vtedy, keď sa fragmenty rovnakého pôvodu naviažu na rôzne miesta flowcelly a vytvoria samostatné klastre. Kópie identického fragmentu tak získajú viacero samostatných čítaní (Ebbert et al. 2016).

Duplicitné čítania môžu viesť k nadhodnoteniu počtu čítaní podporujúcich určitý variant. Ak sa navyše v skorých cykloch PCR objaví chyba, môže sa následne namnožiť do veľkého počtu identických kópií. Toto môže viesť k identifikácii falošných variantov. Deduplikácia teda obmedzuje vplyv týchto artefaktov a prispieva k presnejšiemu odhadu frekvencie genetických variantov (Ebbert et al. 2016).

Pri deduplikácii sa využívajú unikátne molekulárne identifikátory spomenuté v sekcii [\[UMI\]](#UMI){reference-type="ref" reference="UMI"}. Pri absencii UMI sa duplicitné čítania identifikujú len na základe ich mapovania na referenčný genóm. Čítania s rovnakou pozíciou zarovnania a rovnakou orientáciou sa považujú za duplikáty (Zverinova and Guryev 2021-12-16).

Na deduplikáciu sa bežne využíva balík Samtools (Danecek et al. 2021), ktorý umožňuje identifikovať duplikáty na základe pozície čítaní, alebo balík UMI-tools, ktorý zohľadňuje aj prítomnosť UMI (UMI-tools Development Team 2026).

### Orezanie primerov

Pri cielenom sekvenovaní sa pred identifikáciou genetických variantov odporúča odstrániť zvyšky primerových sekvencií. Namapované čítania totiž okrem samotnej cieľovej oblasti (insertu) často obsahujú aj sekvencie jedného alebo oboch génovo špecifických primerov.

Počas procesu mapovania je vhodné tieto primery v čítaniach ponechať, keďže ich vysoká podobnosť s referenčným genómom môže prispieť k presnejšiemu zarovnaniu. Tento prístup znižuje riziko straty variantov nachádzajúcich sa na koncoch čítaní. Mapovacie algoritmy by ich inak mohli vyhodnotiť ako nepresné a automaticky ich orezať pomocou techniky *soft-clipping* (Satya and DiCarlo 2014).

Po dokončení mapovania sa však odporúča primerové sekvencie odstrániť, respektíve vykonať ich *soft-clipping*. Ich ponechanie v bioinformatickom spracovaní by mohlo viesť k identifikácii falošne pozitívnych variantov, napríklad v dôsledku syntetických mismatchov v primerových sekvenciách alebo v dôsledku chýb sekvenovania na koncoch čítaní.

Zároveň môže dochádzať aj k skresleniu (zriedeniu) frekvencie variantných alel (VAF, z angl. Variant Allele Frequency), najmä u panelov s prekrývajúcimi sa amplikónmi. Sekvencie primerov sú zvyčajne zhodné s referenčným genómom, a preto sa pri analýze môžu prejaviť ako *wild-type* alely (Satya and DiCarlo 2014; Au et al. 2017-5-8).

K orezaniu primerov po mapovaní je možné využiť príkaz `ampliconclip` z balíku Samtools (Danecek et al. 2021).

### Pokrytie cieľových oblastí

Pred detekciou variantov je pri cielenom sekvenovaní vhodné vyhodnotiť hĺbku pokrytia cieľových oblastí (Koboldt 2020). Hĺbka pokrytia vyjadruje počet čítaní, ktoré sa prekrývajú v konkrétnej nukleotidovej pozícii. Vyššia hĺbka pritom priamo zvyšuje presnosť detekcie somatických variantov (Chen et al. 2026).

Tento parameter podmieňuje limit detekcie (LoD, z angl. *Limit of Detection*), ktorý predstavuje najnižšiu alelovú frekvenciu variantu spoľahlivo identifikovateľnú pri danej hĺbke sekvenovania (Jennings et al. 2017). S narastajúcim pokrytím sa hodnota LoD znižuje, čo umožňuje zachytiť aj minoritné subklonálne mutácie. Nedostatočné alebo neuniformné pokrytie môže viesť k falošne negatívnym výsledkom, najmä pri detekcii variantov s nízkou alelovou frekvenciou (Cibulskis et al. 2013-2-10; Zverinova and Guryev 2021-12-16).

Pre tento krok sa v bioinformatickej praxi často využívajú nástroje z balíkov Picard (Broad Institute 2026) alebo Bedtools (Quinlan and Hall 2010).

## Identifikácia genetických variantov

Výstupom predchádzajúceho spracovania sú dáta pripravené na proces identifikácie genetických variantov (variant calling). Cieľom tohto procesu je vyhľadať rozdiely medzi analyzovanou vzorkou a referenčnými sekvenciami. Na to bezsprostredne nadväzuje krok filtrácie, ktorý preveruje zachytené varianty (Cibulskis et al. 2013-2-10).

### Typy genetických variantov

Varianty pritom môžu mať rôznu podobu. Môže ísť o:

- SNVs (z angl. *Single Nucleotide Variants*) - substitúcie jedinej bázy v porovnaní s referenciou.

- krátke indely - krátke inzercie a delécie s dĺžkou približne do 20 bp.

- SVs (z angl. *Structural Variants*) - väčšie zmeny genómovej štruktúry, zvyčajne s dĺžkou nad 20 bp, medzi ktoré patria napríklad inverzie, translokácie alebo zmeny počtu kópií sekvencie (CNVs, z angl. *Copy Number Variants*), zahŕňajúce delécie alebo duplikácie väčších genómových úsekov (Zverinova and Guryev 2021-12-16).

Variant calling môže slúžiť k detekcii zárodočných či somatických variantov. Zárodočný variant je genetický variant prítomný v zárodočnej línii, ktorý môže byť prenesený z rodičov na potomstvo a typicky je prítomný vo väčšine buniek organizmu. Somatický variant vzniká počas života organizmu v somatických bunkách a je prítomný len v určitej populácii buniek. Napríklad v nádorových bunkách, pričom na potomstvo sa neprenáša.

V tejto práci je cieľom vykonať práve somatický variant calling. Obvykle porovnáva vzorku z postihnutého tkaniva s párovou kontrolnou vzorkou z normálneho tkaniva toho istého pacienta. To umožňuje jednoduchšie odlíšiť somatické a zárodočné varianty. Somatický variant calling je však možné vykonať aj bez kontrolnej vzorky. V tomto prípade je identifikácia variantov založená najmä na porovnaní s referenčným genómom a na ďalších filtračných a štatistických postupoch.

### Detekcia somatických variantov pomocou Mutect2 {#Mutect2}

K identifikácii somatických mutácií je možné využiť nástroj Mutect2 (Cibulskis et al. 2013-2-10), ktorý je súčasťou balíka GATK (z angl. *Genome Analysis Toolkit*). Je určený na detekciu krátkych variantov, akými sú SNVs a krátke indely.

Somatický variant calling sa v súčasnosti využíva predovšetkým na identifikáciu a analýzu špecifických genetických zmien v nádoroch. Táto úloha však predstavuje značnú výzvu. Klinické vzorky odobraté z nádorov totiž takmer vždy obsahujú aj určitú prímes okolitého zdravého tkaniva. Okrem toho samotný nádor nebýva geneticky jednotný, ale je tvorený rôznymi subpopuláciami buniek s odlišnými mutáciami. V dôsledku týchto faktorov sa hľadané somatické mutácie nemusia nachádzať vo všetkých bunkách analyzovanej vzorky. Naopak, v sekvenačných dátach často vykazujú veľmi nízku alelovú frekvenciu.

Nástroj Mutect2 je navrhnutý na riešenie týchto problémov. Na rozdiel od nástrojov pre detekciu zárodočných variantov, algoritmus Mutect2 nepredpokladá fixnú ploidiu organizmu. Nepracuje teda s predpokladom, že variant musí zodpovedať heterozygotnému (VAF $\approx$ 50%) alebo homozygotnému (VAF $\approx$ 100%) stavu. Využíva Bayesovský štatistický model, ktorý odhaduje pravdepodobnosť prítomnosti somatického variantu na základe pozorovaných sekvenačných dát, pričom zohľadňuje možnú nízku alelovú frekvenciu variantu (Cibulskis et al. 2013-2-10).

Nástroj Mutect2 sa pri identifikácii variantov nespolieha výlučne na pôvodné mapovanie čítaní. V oblastiach s prítomnosťou potenciálneho variantu vykonáva lokálne *de novo* zarovnanie čítaní (angl. *local assembly and realignment*). Tento prístup zvyšuje presnosť detekcie indelov a eliminuje falošné nálezy spôsobené nesprávnym mapovaním (Benjamin et al. 2019).

### Filtrácia

Proces identifikácie somatických variantov je v GATK pipeline rozdelený do dvoch hlavných krokov. Najprv dochádza k volaniu veľkého množstva kandidátnych variantov a potom k ich dôkladnej filtrácii (Broad Institute 2024).

#### Primárne filtre

V prvom kroku (nástroj `Mutect2`) algoritmus prehľadáva genóm a s vysokou citlivosťou označuje všetky odchýlky od referenčnej sekvencie. Aby sa predišlo zahlteniu výsledkov falošne pozitívnymi nálezmi, do Bayesovského modelu sú už v tejto fáze využité apriórne pravdepodobnosti, ktoré slúžia ako primárne filtre (Broad Institute 2024):

- **Populačný zdroj zárodočných variantov**:

  Súbor špecifikovaný parametrom `--germline-resource` poskytuje informácie o výskyte a frekvencii konkrétnych genetických variantov v populácii. Slúži na automatické rozpoznanie a odstránenie bežných vrodených polymorfizmov, ktoré by inak mohli byť nesprávne interpretované ako mutácie vzniknuté v nádore.

- **Panel normálnych vzoriek** (PoN, z angl. *Panel of Normals*):

  Ide o referenčnú databázu, ktorá slúži na zachytenie opakujúcich sa technických chýb a sekvenačných artefaktov špecifických pre konkrétnu sekvenačnú platformu, prípravu knižníc a zvolený postup bioinformatického spracovania. Databázu možno špecifikovať parametrom `--panel-of-normals`.

  S pomocou nástroja `CreateSomaticPanelOfNormals` je možné pripraviť vlastný PoN. To umožňuje odfiltrovať systémové chyby typické priamo pre prístroje a procesy použité pri spracovaní analyzovaných dát.

- **Párová kontrolná vzorka** (angl. *matched-normal*):

  Ak je k dispozícii párová kontrolná vzorka zo zdravého tkaniva, Mutect2 ju priamo porovnáva s nádorovou vzorkou. Toto zabezpečí spoľahlivú filtráciu individuálnych zárodočných variantov pacienta. Párová kontrolná vzorka sa určuje pod parametrom `-normal`.

V režime *tumor-only*, čiže bez párovej kontrolnej vzorky nie je dostupný najsilnejší filter na odstránenie zárodočných variantov pacienta a artefaktov, čo zvyšuje nároky na kvalitu použitého PoN a presnosť populačných databáz.

#### Modelovanie artefaktov a finálna filtrácia

V druhom kroku GATK Best Practices odporúča modelovať ďalšie špecifické zdroje chýb, ktoré by mohli skresliť výsledky (Broad Institute 2024):

- **Krížovú kontamináciu**:

  Kontaminácia vzorky cudzou DNA môže pre Mutect2 vyzerať ako prítomnosť nízkofrekvenčných somatických mutácií. S pomocou nástrojov `GetPileupSummaries` a `CalculateContamination` je možné odhadnúť mieru tejto kontaminácie.

- **Bias orientácie čítania** (angl. *Read orientation bias*):

  Extrakcia DNA z FFPE blokov a ďalšie spracovanie DNA môže viesť k poškodeniu molekúl. Môže dochádzať k umelým substitúciám, ktoré sa často prejavia iba na jednom vlákne DNA (Zverinova and Guryev 2021-12-16; Guo et al. 2022-9-6). Pre ich identifikáciu sa využíva nástroj `LearnReadOrientationModel`.

Finálnu filtráciu vykonáva nástroj `FilterMutectCalls`, ktorý kombinuje zoznam kandidátnych variantov s modelmi kontaminácie a orientačného skreslenia. Program tak vyberie len tie varianty, ktoré spĺňajú štatistické kritériá a pridelí im značku `PASS` (Broad Institute 2024). Výsledné súbory sú vo formáte VCF.

### Formát VCF

Formát VCF (z angl. *Variant Call Format*) je štandardizovaný formát súboru na zápis genetických variantov. Bol vyvinutý v rámci projektu 1000 Genomes Project a v súčasnosti patrí medzi najpoužívanejšie formáty v oblasti genomiky (Danecek et al. 2011-6-7).

Každý VCF súbor je rozdelený na dve hlavné časti: hlavičku a dátovú časť. Hlavička obsahuje metadáta označené prefixom \"`##`\", ktoré špecifikujú verziu formátu, použitý referenčný genóm a poskytujú definície pre polia dátovej sekcie INFO, FILTER a FORMAT. Tieto definície sú dôležité pre správnu interpretáciu dát, keďže sa môžu líšiť v závislosti od použitého bioinformatického nástroja. Posledný riadok hlavičky určuje názvy stĺpcov v dátovej časti (Danecek et al. 2011-6-7).

Dátová sekcia súboru pozostáva z tabulátorom oddelených polí, ktoré poskytujú detailné informácie o každom variante. Každý riadok pritom reprezentuje jeden identifikovaný variant. Základ dátovej sekcie tvorí osem povinných stĺpcov. Tie definujú pozíciu variantu v genóme (CHROM, POS), jeho identifikátor (ID), referenčnú alelu (REF), alternatívne alely (ALT), kvalitu volania variantu (QUAL), informáciu o prechode filtrom (FILTER) a dodatočné anotácie (INFO). Hodnota QUAL pritom predstavuje Phred-skóre vyjadrujúce pravdepodobnosť správnosti detekcie variantu (Danecek et al. 2011-6-7).

## Funkčná anotácia variantov

Identifikované genetické varianty samy osebe neposkytujú informáciu o svojom biologickom ani klinickom význame. Na ich interpretáciu je potrebná funkčná anotácia. V tomto procese sú varianty porovnávané s referenčnými databázami genómov, transkriptov a známych genetických polymorfizmov. Výsledkom anotácie je priradenie informácií o tom, ktorý gén je variantom zasiahnutý a aký môže byť jeho funkčný dopad na úrovni proteínu (napr. `missense_variant` - zámena aminokyseliny, `stop_gained` - vznik predčasného stop kodónu, `frameshift_variant` - posun čítacieho rámca). Súčasťou anotácie môže byť aj informácia o potenciálnom klinickom význame daného variantu (Larson et al. 2023; McLaren et al. 2016-6-6).

Pre správnu anotáciu sú nevyhnutné tieto tri komponenty: referenčný genóm (zhodný s genómom použitom pri mapovaní), súbor anotácií génových modelov (definujúci hranice exónov a intrónov) a externé databázy. Medzi ne patria populačné databázy, ktoré poskytujú informácie o frekvencii variantov v populácii, a klinické databázy, ktoré obsahujú poznatky o ich vzťahu k ochoreniam.

Pred samotnou anotáciou je možné pomocou nástroja `bcftools` (Danecek et al. 2021) odfiltrovať varianty na základe kvality, napríklad výberom len tých, ktoré sú označené príznakom `PASS`. Tým sa zabezpečí, že do následnej interpretácie vstupujú len vysoko spoľahlivé varianty.

### Ensembl VEP

Na anotáciu variantov je možné využiť nástroj Ensembl VEP (*Variant Effect Predictor*), ktorý vyhľadáva prekryv genomických súradníc variantu s anotáciami génov a transkriptov. Samotná anotácia môže prebiehať aj v offline režime s využitím lokálnej cache pre konkrétnu referenčnú zostavu (McLaren et al. 2016-6-6).

Dôležitým aspektom anotácie je fakt, že jeden variant môže zasahovať viacero transkriptov (izoforiem) toho istého génu, pričom v každom môže mať odlišný vplyv. Štandardný výstup VEP preto generuje samostatný riadok pre každú zasiahnutú izoformu. Aby sa predišlo duplicitám pri následnej štatistickej analýze, je možné tiež využiť parameter `--flag-pick`. Algoritmus v tomto prípade identifikuje a označí jeden biologicky najrelevantnejší transkript pre každý variant. Prioritizuje napríklad kanonické transkripty alebo tie s najvážnejším dopadom (McLaren et al. 2016-6-6).

Parameter `--everything` zas umožňuje získať komplexné údaje o variantoch vrátane predikcie ich funkčného dopadu, populačných frekvencií a dostupných klinických anotácií. Štandardným výstupom procesu anotácie pomocou Ensembl VEP je tabuľkový súbory vo formáte TSV (z angl. *Tab-Separated Values*), no je možné získať aj iné formáty ako napríklad VCF (McLaren et al. 2016-6-6).

# Zoznam použitej literatúry
::: {#refs}
:::

::: {#ref-fastqc .csl-entry}

Andrews, Simon. 2010. *FastQC: A Quality Control Tool for High Throughput Sequence Data*. [Https://www.bioinformatics.babraham.ac.uk/projects/fastqc/](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/){.uri}. <https://www.bioinformatics.babraham.ac.uk/projects/fastqc/>.
:::

::: {#ref-Au201758 .csl-entry}

Au, Chun Hang, Dona N. Ho, Ava Kwong, Tsun Leung Chan, and Edmond S. K. Ma. 2017-5-8. "BAMClipper: Removing Primers from Alignments to Minimize False-Negative Mutations in Amplicon Next-Generation Sequencing." *Scientific Reports* 7 (1): 1567. <https://doi.org/10.1038/s41598-017-01703-6>.
:::

::: {#ref-Benjamin861054 .csl-entry}

Benjamin, David, Takuto Sato, Kristian Cibulskis, Gad Getz, Chip Stewart, and Lee Lichtenstein. 2019. "Calling Somatic SNVs and Indels with Mutect2." *bioRxiv*, ahead of print. <https://doi.org/10.1101/861054>.
:::

::: {#ref-BroadSomatic .csl-entry}

Broad Institute. 2024. *Somatic Short Variant Discovery (SNVs + Indels)*. [Https://gatk.broadinstitute.org/hc/en-us/articles/360035894731-Somatic-short-variant-discovery-SNVs-Indels-](https://gatk.broadinstitute.org/hc/en-us/articles/360035894731-Somatic-short-variant-discovery-SNVs-Indels-){.uri}.
:::

::: {#ref-Picard2026 .csl-entry}

Broad Institute. 2026. *Picard Tools*. [Http://broadinstitute.github.io/picard](http://broadinstitute.github.io/picard){.uri}.
:::

::: {#ref-CabelloAguilar2023124 .csl-entry}

Cabello-Aguilar, Simon, Julie A. Vendrell, and Jérôme Solassol. 2023. "A Bioinformatics Toolkit for Next-Generation Sequencing in Clinical Oncology." *Current Issues in Molecular Biology* 45 (12): 9737--52. <https://doi.org/10.3390/cimb45120608>.
:::

::: {#ref-Chen201891 .csl-entry}

Chen, Shifu, Yanqing Zhou, Yaru Chen, and Jia Gu. 2018. "Fastp: An Ultra-Fast All-in-One FASTQ Preprocessor." *Bioinformatics* 34 (17): i884--90. <https://doi.org/10.1093/bioinformatics/bty560>.
:::

::: {#ref-Chen20200226 .csl-entry}

Chen, Zixi, Yuchen Yuan, Xiaoshi Chen, et al. 2026. "Systematic Comparison of Somatic Variant Calling Performance Among Different Sequencing Depth and Mutation Frequency." *Scientific Reports* 10 (1): 3501--1. <https://doi.org/10.1038/s41598-020-60559-5>.
:::

::: {#ref-Cibulskis2013210 .csl-entry}

Cibulskis, Kristian, Michael S Lawrence, Scott L Carter, et al. 2013-2-10. "Sensitive Detection of Somatic Point Mutations in Impure and Heterogeneous Cancer Samples." *Nature Biotechnology* 31 (3): 213--19. <https://doi.org/10.1038/nbt.2514>.
:::

::: {#ref-Cock20091216 .csl-entry}

Cock, Peter J. A., Christopher J. Fields, Naohisa Goto, Michael L. Heuer, and Peter M. Rice. 2009-12-16. "The Sanger FASTQ File Format for Sequences with Quality Scores, and the Solexa/Illumina FASTQ Variants." *Nucleic Acids Research* 38 (6): 1767--71. <https://doi.org/10.1093/nar/gkp1137>.
:::

::: {#ref-Danecek201167 .csl-entry}

Danecek, Petr, Adam Auton, Goncalo Abecasis, et al. 2011-6-7. "The Variant Call Format and VCFtools." *Bioinformatics* 27 (15): 2156--58. <https://doi.org/10.1093/bioinformatics/btr330>.
:::

::: {#ref-10.1093/gigascience/giab008 .csl-entry}

Danecek, Petr, James K Bonfield, Jennifer Liddle, et al. 2021. "[Twelve years of SAMtools and BCFtools]{.nocase}." *GigaScience* 10 (2). <https://doi.org/10.1093/gigascience/giab008>.
:::

::: {#ref-Ebbert20160701 .csl-entry}

Ebbert, Mark, Mark E. Wadsworth, Lyndsay A. Staley, et al. 2016. "Evaluating the Necessity of PCR Duplicate Removal from Next-Generation Sequencing Data and a Comparison of Approaches." *BMC Bioinformatics* 17 (S7): 239--39. <https://doi.org/10.1186/s12859-016-1097-3>.
:::

::: {#ref-Ewels2016616 .csl-entry}

Ewels, Philip, Måns Magnusson, Sverker Lundin, and Max Käller. 2016-6-16. "MultiQC: Summarize Analysis Results for Multiple Tools and Samples in a Single Report." *Bioinformatics* 32 (19): 3047--48. <https://doi.org/10.1093/bioinformatics/btw354>.
:::

::: {#ref-Guo202296 .csl-entry}

Guo, Qingli, Eszter Lakatos, Ibrahim Al Bakir, Kit Curtius, Trevor A. Graham, and Ville Mustonen. 2022-9-6. "The Mutational Signatures of Formalin Fixation on the Human Genome." *Nature Communications* 13 (1). <https://doi.org/10.1038/s41467-022-32041-5>.
:::

::: {#ref-Jennings2017 .csl-entry}

Jennings, Lawrence J., Maria E. Arcila, Christopher Corless, et al. 2017. "Guidelines for Validation of Next-Generation Sequencing--Based Oncology Panels." *The Journal of Molecular Diagnostics* 19 (3): 341--65. <https://doi.org/10.1016/j.jmoldx.2017.01.011>.
:::

::: {#ref-DanielCKoboldt20201026 .csl-entry}

Koboldt, Daniel C. 2020. "Best Practices for Variant Calling in Clinical Sequencing." *Genome Medicine* 12 (1): 91--91. <https://doi.org/10.1186/s13073-020-00791-w>.
:::

::: {#ref-seqera2025 .csl-entry}

Labs, Seqera. 2025. *MultiQC Reports Documentation*. [Https://seqera.io/multiqc/](https://seqera.io/multiqc/){.uri}. <https://docs.seqera.io/multiqc/>.
:::

::: {#ref-clinvar .csl-entry}

Landrum, Melissa J., Jennifer M. Lee, Mark Benson, et al. 2015-11-17. "ClinVar: Public Archive of Interpretations of Clinically Relevant Variants." *Nucleic Acids Research* 44 (D1): D862--68. <https://doi.org/10.1093/nar/gkv1222>.
:::

::: {#ref-Larson2023 .csl-entry}

Larson, Nicholas Bradley, Ann L. Oberg, Alex A. Adjei, and Liguo Wang. 2023. "A Clinician's Guide to Bioinformatics for Next-Generation Sequencing." *Journal of Thoracic Oncology* 18 (2): 143--57. <https://doi.org/10.1016/j.jtho.2022.11.006>.
:::

::: {#ref-li2013aligningsequencereadsclone .csl-entry}

Li, Heng. 2013. *Aligning Sequence Reads, Clone Sequences and Assembly Contigs with BWA-MEM*. [Https://arxiv.org/pdf/1303.3997](https://arxiv.org/pdf/1303.3997){.uri}. <https://arxiv.org/pdf/1303.3997>.
:::

::: {#ref-McLaren201666 .csl-entry}

McLaren, William, Laurent Gil, Sarah E. Hunt, et al. 2016-6-6. "The Ensembl Variant Effect Predictor." *Genome Biology* 17 (1). <https://doi.org/10.1186/s13059-016-0974-4>.
:::

::: {#ref-Quinlan2010 .csl-entry}

Quinlan, Aaron R., and Ira M. Hall. 2010. "BEDTools: A Flexible Suite of Utilities for Comparing Genomic Features." *Bioinformatics* 26 (6): 841--42. <https://doi.org/10.1093/bioinformatics/btq033>.
:::

::: {#ref-SAMv1 .csl-entry}

SAM/BAM Format Specification Working Group. 2024. *Sequence Alignment/Map Format Specification, Version 1.6*. [Https://samtools.github.io/hts-specs/SAMv1.pdf](https://samtools.github.io/hts-specs/SAMv1.pdf){.uri}.
:::

::: {#ref-VijayaSatya2014 .csl-entry}

Satya, Ravi Vijaya, and John DiCarlo. 2014. "Edge Effects in Calling Variants from Targeted Amplicon Sequencing." *BMC Genomics* 15 (1): 1073. <https://doi.org/10.1186/1471-2164-15-1073>.
:::

::: {#ref-UMITools2026 .csl-entry}

UMI-tools Development Team. 2026. *UMI-Tools Documentation*. [Https://umi-tools.readthedocs.io/en/latest/index.html](https://umi-tools.readthedocs.io/en/latest/index.html){.uri}.
:::

::: {#ref-Zverinova20211216 .csl-entry}

Zverinova, Stepanka, and Victor Guryev. 2021-12-16. "Variant Calling: Considerations, Practices, and Developments." *Human Mutation* 43 (8): 976--85. <https://doi.org/10.1002/humu.24311>.
:::
::::::::::::::::::::::::::::::
