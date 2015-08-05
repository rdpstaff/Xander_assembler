## Xander Gene-targeted Metagenomic Assembler 

Metagenomics can provide important insight into microbial communities. However, assembling metagenomic datasets has proven to be computationally challenging. We present a novel method for targeting assembly of specific protein-coding genes using a graph structure combining both de Bruijn graphs and protein HMMs. The inclusion of HMM information guides the assembly, with concomitant gene annotation. 

We have been using Xander to assemble contigs for both phylogenetic marker gene and functional marker genes from soil metegenomic data ranging from 5 GB to 350 GB. We compared our method to a recently published bulk metagenome assembly method and a recently published gene-targeted assembler and found our method produced more, longer and higher-quality gene sequences. Xander can detect low-abundance genes and low-abundance organisms. HMMs can be tailored to the targeted genes, allowing flexibility to improve annotation over generic annotation pipelines.

Trivia:: The name Xander comes from Alexander the Great, who cut the Gordian knot.

Children and lunatics cut the Gordian knot, which the poet spends his life patiently trying to untie.

	- Jean Cocteau

### Required tools

* RDPTools (https://github.com/rdpstaff/RDPTools)
* Python 2.7+
* Java 1.6+
* HMMER 3.1 (http://hmmer.janelia.org, If using HMMER 3.0 add --allcol to bin/run_xander_skel.sh )
* UCHIME (http://drive5.com/usearch/manual/uchime_algo.html)

### Citation
Wang, Q., J. A. Fish, M. Gilman, Y. Sun, C. T. Brown, J. M. Tiedje and J. R. Cole. Xander: Employing a Novel Method for Efficient Gene-Targeted Metagenomic Assembly. Microbiome.2015, 3:32. DOI: 10.1186/s40168-015-0093-6. URL: http://www.microbiomejournal.com/content/3/1/32. 

Presentation about Xander can be found in http://rdp.cme.msu.edu/download/posters/Xander_assembler_022015.pdf

## Xander Assembly Analysis


### Quickstart using shell script
Use testdata as an example. Make a copy of bin/xander_setenv.sh and change path variables to be the absolute paths in your system. For your samples, you may also need to adjust the de Bruijn Graph Build Parameters, especially the FILTER_SIZE for bloom filter size. 

The following example commands will attempt to run all the three steps "build", "find" and "search" for the genes "nifH nirK rplB nosZ" specified in the input param. It creates an assembly output directory "k45" for kmer length of 45. It makes an output directory for each gene inside "k45" and saves all the output in the gene output directory. 

```
bash
cd testdata
cp ../bin/xander_setenv.sh my_xander_setenv.sh
# edit the parameters in my_xander_setenv.sh 
../bin/run_xander_skel.sh my_xander_setenv.sh "build find search" "nifH nirK rplB nosZ"
```

You can also run the three steps separately, or search multiple genes in parallel.
```
../bin/run_xander_skel.sh my_xander_setenv.sh "build find" "nifH nirK rplB nosZ"
../bin/run_xander_skel.sh my_xander_setenv.sh "search" "nifH" &
../bin/run_xander_skel.sh my_xander_setenv.sh "search" "nirK" &
../bin/run_xander_skel.sh my_xander_setenv.sh "search" "rplB" &
../bin/run_xander_skel.sh my_xander_setenv.sh "search" "nosZ" &
```
 
Note if you want to rebuild the bloom graph structure, you need to manually delete the .bloom file in the output directory. If you would like to rerun the finding starting kmers for a gene, you need to manually delete that gene output directory.

### Xander Assembly Steps 

Each step can be run separately. Some steps can be run in parallel as suggested below using kmer length of 45 as an example. 

* Build de Bruijn graph, only once for each dataset at given kmer length 
```
 * Input: read files (fasta, fastq or gz format)
 * Output 1: de Bruijn graph (k45.bloom) 
 * Output 2: bloom file stats (k45_bloom_stat.txt). Check the "Predicted false positive rate" in this file (see How to choose the FILTER_SIZE below).
```

* Identify starting kmers (multiple genes should be run together to save time; multithread option)
```
 * Input 1: ref_aligned.faa files from gene ref directories  
 * Input 2: read files
 * Output: starting nucleotide kmers (gene_starts.txt for each gene)
```

* Assemble contigs (each gene can be done in parallel, length cutoff or HMM score cutoff filters are used)
```
 * Input 1: forward and reverse HMMs (for_enone.hmm and rev_enone.hmm)
 * Input 2: de Bruijn graph (k45.bloom)
 * Input 3: starting kmers (gene_starts.txt)
 * Output 1: unique merged protein contigs (prot_merged_rmdup.fasta)
 * Output 2: merged nucleotide contigs (nucl_merged.fasta)
 * Output 3: unmerged nucleotide and protein contigs (gene_starts.txt_nucl.fasta and gene_starts.txt_prot.fasta)
```

* Cluster (RDP mcClust https://github.com/rdpstaff/Clustering. Longest contigs are chosen as the representative contigs )
```
 * Input 1: prot_merged_rmdup.fasta
 * Output 1: representative contigs at 99% aa identity (nucl_rep_seqs.fasta and prot_rep_seqs.fasta)
 * Output 2: aligned protein contigs (aligned.fasta)
 * Output 3: complete linkeage cluster output 
```

* Chimera removal (UCHIME)
```
 * Input 1: representative nucleotide contigs (nucl_rep_seqs.fasta)
 * Input 2: gene nucleotide reference set (originaldata/nucl.fa from gene ref directory)
 * Output 1: UCHIME output (result_uchimealn.txt, results.uchime.txt)
 * Output 2: quality_filtered nucleotide representative contigs (final_nucl.fasta)
 * Output 3: quality_filtered protein representative contigs (final_prot.fasta and final_prot_aligned.fasta)
```

**Note: the quality-filtered contigs in final_nucl.fasta, final_prot.fasta and final_prot_aligned.fasta should be used as the final set of contigs assembled by Xander.**

The following post-assembly analysis are included in run_xander_skel.sh. 

* Nearest reference matches (RDP FrameBot https://github.com/rdpstaff/Framebot, can also use RDP Protein Seqmatch)
```
 * Input 1: quality_filtered nucleotide representative contigs (final_nucl.fasta)
 * Input 2: gene protein reference set (originaldata/framebot.fa from gene ref directory)
 * Outputs: the nearest reference seq and % aa identity (framebot.txt)
```

* Read mapping, contig coverage and kmer abundance (RDP KmerFilter, multithread option)
```
 * Input 1: quality_filtered nucleotide representative contigs (final_nucl.fasta)
 * Input 2: read files
 * Output 1: contig coverage (coverage.txt, can be used to estimate gene abundance and adjust sequence abundance)
 * Output 2: kmer abundance (abundance.txt)
```

* Taxonomic abundance 
```
 * Input 1: contig coverage (coverage.txt)
 * Input 2: the nearest reference seq (framebot.txt) 
 * Input 3: gene protein reference set (originaldata/framebot.fa from gene ref directory) 
 * Output: taxonomic abundance adjusted by coverage, group by lineage (phylum/class) (taxonabund.txt)
```

* Beta diversity analysis (not included in run_xander_skel.sh but can be done using a separate script)

A script in bin/get_OTUabundance.sh is provided to create coverage-adjusted OTU abundance data matrix from contigs of same gene from multiple samples. The data matrix can then imported to R or PhyloSeq for more extensive analysis and visualization functions (see http://rdp.cme.msu.edu/tutorials/stats/RDPtutorial_statistics.html)
```
 * Input 1: aligned protein contig files (final_prot_aligned.fasta)
 * Input 2: contig coverage (coverage.txt)
 * Output: data matrix file with the OTU abundance at the each distance
```

 
### Parameters

#### How to choose the FILTER_SIZE for your dataset?
For count 1 bloom, the size of the bloom filter is approximately 2^(FILTER_SIZE-3) bytes. The memory needed for Java is less than double the size of the bloom filter. Increase the FILTER_SIZE if the predicted false positive rate (in output file *_bloom_stat.txt) is greater than 1%. Based on our experience with soil metagenome data, FILTER_SIZE 32 (1 GB memory) for data file size of 2GB, 35 (8 GB) for file size of 6GB, 38 (64 GB ) for file size of 70GB, 40 (256 GB) for file size of 350GB were appropriate. For count 2 bloom filter, double the memory sizes. 

#### Analysis Parameters
* SEQFILE -- Absolute path to the sequence files. Can use wildcards to point to multiple files (fasta, fataq or gz format)
* genes -- Genes to assemble (supported out of the box: rplB, nirK, nirS, nifH, nosZ, amoA)
* SAMPLE_SHORTNAME -- a short name for your sample, prefix of contig IDs (needed when pool contigs from multiple samples)

#### DBG Parameters
* MAX_JVM_HEAP -- Maximum amount of memory DBG processes can use (must be larger than FILTER_SIZE below)
* K_SIZE -- K-mer size to assemble at, must be divisible by 3 (recommend 45, maximum 63)
* FILTER_SIZE -- size of the bloom filter, 2**FILTER_SIZE, 38 = 32 GB, 37 = 16 GB, 36 = 8 GB, 35 = 4 GB, increase FILTER_SIZE if the bloom filter predicted false positive rate is greater than 1%
* MIN_COUNT=1 -- minimum kmer occurrence in SEQFILE to be included in the final bloom filter

#### Contig Search Parameters
* PRUNE=20 -- prune the search if the score does not improve after n_nodes (default 20, set to 0 to disable pruning)
* PATHS=1 -- number of paths to search for each starting kmer, default 1 returns the shortest path
* LIMIT_IN_SECS=100 -- number of seconds a search allowed for each kmer, recommend 100 secs for 1 shortest path, need to increase if PATHS is large 

#### Contig Merge Parameters
* MIN_BITS=50 --mimimum assembled contigs bit score
* MIN_LENGTH=150  -- minimum assembled protein contigs

#### Other Paths
* JAR_DIR -- Path to jar files for Xander/ReadSeq/FrameBot/KmerFilter (from RDPTools repository)
* REF_DIR -- Path to Xander_assembler


### Per Gene Preparation, requires biological insight!

Reference sequence files and models for each gene targeted for assembly are placed in a gene ref directory inside the Xander_assembler/gene_resource directory. The analysis pipeline is preconfigured with _rplB_ gene, and nitrogen cycling genes including _nirK_, _nirS_, _nifH_, _nosZ_ and _amoA_.

A subdirectory originaldata should be created inside each gene ref directory, four files are required for preparing HMMs and post-assembly processing:
* gene.seeds: a small set of protein sequences in FASTA format, used to build gene.hmm, forward and reverse HMMs. Can be downloaded from FunGene (http://fungene.cme.msu.edu).
* gene.hmm: this is the HMM built from gene.seeds using original HMMER3. This is used to build for_enone.hmm and align contigs after assembly. Can be downloaded from FunGene.
* framebot.fa: a large near full length known protein set for identifying start kmers and FrameBot nearest matching. More diversity is better, more sequences means more starting points (more computational time) but less susceptible to noise than model creation. Prefer near full-length and well-annotated sequences. Filter with Minimum HMM Coverage at least 80 (%).
* nucl.fa: a large near full length known set used by UCHIME chimera check.

The gene ref directory must have three files for Xander assembly. A script in **bin/prepare_gene_ref.sh** is provided to build specialized forward and reverse HMMs using hmmer-3.0_xanderpatch, a modified version of HMMMER3.0. The modified version is tuned to detect close orthologs. Three output files will be written to the gene ref directory:
* for_enone.hmm and rev_enone.hmm for the forward and reverse HMMs respectively. This is used to assemble gene contigs.
* A ref_aligned.faa file containing a set of protein reference sequences aligned with for_enone.hmm. This is used to identify starting kmers. Need to manually examine the alignment using Jalview or alignment viewing tool to spot any badly aligned sequences. If found, it is likely there are no sequences in gene.seeds close these sequences. You need to valide these problem sequences to see they are from the gene you are interested, then either remoe them or add some representative sequences to gene.seeds and repeat the prepartion steps.


**How to apply Xander patch to hmmer-3.0?**
```
* Download hmmer-3.0.tar.gz from ftp://selab.janelia.org/pub/software/hmmer3/3.0/
* Unzip and untar hmmer-3.0.tar.gz, you will get a directory called hmmer-3.0. Rename hmmer-3.0 to hmmer-3.0_xanderpatch.
* Apply the patch file using the patch file hmmer-3.0_Xander_patch.txt:
  patch hmmer-3.0_xanderpatch/src/p7_prior.c < Xander_assembler/bin/hmmer-3.0_Xander_patch.txt
* Follow the instructions from hmmer-3.0_xanderpatch/INSTALL to install.
```
