## Xander gene_targeted Assembler analysis pipeline

### Required tools

* RDPTools (https://github.com/rdpstaff/RDPTools)
* Python 2.7+
* Java 1.6+
* HMMER 3.1 (http://hmmer.janelia.org, If using HMMER 3.0 add --allcol to bin/run_xander.sh )
* UCHIME (http://drive5.com/usearch/manual/uchime_algo.html)

### Citation
Wang, Q., J. A. Fish, M. Gilman, Y. Sun, C. T. Brown, J. M. Tiedje and J. R. Cole. Xander: gene-targeted metagenomic assembler. Submitted.

### Per Gene Preparation:

Reference sequence files and models for each gene targeted for assembly are placed in a gene directory inside the Xander_assembler directory. The analysis pipeline is preconfigured with rplB gene, and nitrogen cycling genes including nirK, nirS, nifH, nosZ and amoA.

Reference Set Selection: Select a set of reference sequences (resource: http://fungene.cme.msu.edu/) representative of the gene of interest. More diversity is better, more sequences means more starting points (more computational time) but less susceptible to noise than model creation.

A subdirectory originaldata should be created inside each gene directory, four files are required for preparing HMMs and post processing:
* gene.seeds: a small set of protein sequences in FASTA format, used to build gene.hmm, forward and reverse HMMs. Can be downloaded from FunGene (http://fungene.cme.msu.edu).
* gene.hmm: this is the HMM built from gene.seeds using original HMMER3. This is used to build for_enone.hmm and align contigs after assembly. Can be downloaded from FunGene.
* framebot.fa: a large near full length known protein set for identifying start kmers and FrameBot nearest matching. More diversity is better, more sequences means more starting points (more computational time) but less susceptible to noise than model creation. Prefer near full-length and well-annotated sequences. Filter with Minimum HMM Coverage at least 80 (%). 
* nucl.fa: a large near full length known set used by UCHIME chimera check. 

The gene directory must the following three file for assembly. A script in bin/prepare_gene_ref.sh is provided to build specialized forward and reverse HMMs using hmmer-3.0_xanderpatch, a modified version of HMMMER3.0 which is tuned to detect close orthologs. The output will be written to the gene directory.
* for_enone.hmm and rev_enone.hmm for the forward and reverse HMMs respectively. This is used to assemble gene contigs.
* A ref_aligned.faa file containing a set of protein reference sequences aligned with for_enone.hmm. This is used to identify starting kmers. 


## Xander Assembly Analysis

The analysis pipeline will attempt to assemble all genes specified in the bin/run_xander_skel.sh, which requires a directory for each gene name with the above structure.  See the existing gene directories for further examples.

### Quickstart using shell script
Use testdata as an example. Make a copy of bin/run_xander_skel.sh and change path variables to be the absolute paths in your system. For your samples, you may also need to adjust the de Bruijn Graph Build Parameters, especially the FILTER_SIZE for bloom filter size.

```
bash
cd testdata
cp ../bin/run_xander_skel.sh run_xander.sh
# edit the run_xander.sh
./run_xander.sh
```

The shell script allows to assemble genes in different batches without overwriting the existing results. For example, if nirK and rplB genes have been assembled (or at least completed the starting kmers identifying step), you would like to assemble nosZ genes. You can simply edit run_xander.sh to add "nosZ" to the list of genes and run the same command again. Note if the bloom already exists in the output directory, you need to manually delete the bloom files. If you would like to rerun the assembly for a gene, you need to manually delete that gene output directory.

### Xander Assembly Steps 

Each step can be run separately. Some steps can be run in parallel as suggested below. 

* Build de Bruijn graph, once for each dataset at given kmer size
```
 * Input: read files
 * Output: de Bruijn graph structure
```

* Identify starting kmers (can be done with multiple genes and can be multithreaded )
```
 * Input 1: A larger set of reference sequences ref_aligned.faa  
 * Input 2: read files
 * Output: starting nucleotide kmers, alignment positions, HMM states
```

* Assemble each gene (each gene can be done in parallel)
```
 * Input 1: forward and reverse HMMs
 * Input 2: de Bruijn graph
 * Input 3: starting kmers
 * Output: nucleotide and protein contigs
```

* Post-assembly processing
```
 * Cluster (RDP mcClust)
 * Remove chimeric contigs (UCHIME)
 * Map reads and kmer abundance (RDP KmerFilter can be multithreaded) 
 * Find nearest neighbor of the contigs (RDP FrameBot, RDP ProtSeqMatch)
```

### Parameters

#### How to choose the FILTER_SIZE for your dataset?
The size of the bloom filter (or memory needed) is approximately 2^FILTER_SIZE bits. Increase the FILTER_SIZE if the predicted false positive rate (in output file *_bloom_stat.txt) is greater than 1%. Based on our experience with soil metagenome data, FILTER_SIZE 32 (1/2 GB memory) for data size of 2G, 35 (4 GB memory) for data size of 6G, 38 (32 GB memory) for data size of 70G were appropriate. 

#### Analysis Parameters
* SEQFILE -- Absolute path to the sequence file (_MUST_ be the absolute path)
* genes -- Genes to assemble (supported out of the box: rplB, nirK, nifH), see Gene Directories
* SAMPLE_SHORTNAME -- a short name for your sample, will be used as prefix of contig IDs (needed when pool contigs from multiple samples)

#### DBG Parameters
* MAX_JVM_HEAP -- Maximum amount of memory DBG processes can use (must be larger than FILTER_SIZE below)
* K_SIZE -- K-mer size to assemble at, must be divisible by 3 (recommend 45, minimum 30, maximum 63)
* FILTER_SIZE -- size of the bloom filter, 2**FILTER_SIZE, 38 = 32 gigs, 37 = 16 gigs, 36 = 8 gigs, 35 = 4 gigs, increase FILTER_SIZE if the bloom filter predicted false positive rate is greater than 1%
* MIN_COUNT=1 -- minimum kmer occurrence SEQFILE to be included in the final bloom filter

#### Contig Search Parameters
* PRUNE=20 -- prune the search if the score does not improve after n_nodes (default 20, set to -1 to disable pruning)
* PATHS=1 -- number of paths to search for each starting kmer, default 1 returns the shortest path
* LIMIT_IN_SECS=100 -- number of seconds a search allowed for each kmer, recommend 100 secs for 1 shortest path, need to increase if PATHS is greater than 11

#### Contig Merge Parameters
* MIN_BITS=50 --mimimum assembled contigs bit score
* MIN_LENGTH=150  -- minimum assembled protein contigs

#### Other Paths
* JAR_DIR -- Path to jar files for Xander/ReadSeq/FrameBot/KmerFilter (from RDPTools repository)

