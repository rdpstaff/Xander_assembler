# Xander gene_targeted Assember analysis pipeline

### Required tools

* Python 2.7+
* Java 1.6+
* HMMER 3.1 (http://hmmer.janelia.org, If using 3.0 add --allcol to bin/run_xander.sh )
* UCHIME (http://drive5.com/usearch/manual/uchime_algo.html)

## Per Gene Preparation:

Reference Set Selection: Select a set of reference sequences (resouce: http://fungene.cme.msu.edu/) representative of the gene of interest.  More diversity is better, more sequences means more starting points (more computational time) but less suceptiable to noise than model creation.

Model Construction: A script in bin/prepare_gene_ref.sh is provided to build forward and reverse models (left and right) using hmmer-3.0_xanderpatch, a modified version of HMMMER3.0 which is tuned to detect close othologs.

### Build specialized forward and reverse HMMs 
* Input: a small set of aligned seed sequences (using original HMMER3 program and HMMs from FunGene)
* Output: forward and reverse HMMs for Xander 

## Gene Analysis Directories

Reference sequence files and models for each gene targeted for assembly are placed in a directory in the main analysis directory.  Included with the skeleton analysis pipeline are configurations for assembling rplB, and nitrogen cycling genes such as nirK, nifH and amoA genes.

A gene analysis directory must contain two hidden markov models built with HMMER3 named for_enone.hmm and rev_enone.hmm for the forward and reverse of the gene sequences respectively.  Also a ref_aligned.faa file must contain a set of protein reference sequences aligned with for_enone.hmm.  This file is used to identify starting kmers for assembly. 
A file framebot.fa containing a set of protein reference sequences is also need for FrameBot to find the nearest matches for the assembled contigs.
A file nucl.fa containing a set of nucleotide reference sequences to be used by UCHIME chimera check.

The analysis pipeline will attempt to assemble all genes specified in the bin/run_xander_skel.sh, which requires a directory for each gene name with the above structure.  See the existing gene directories for further examples.

## Analysis

### Quickstart using shell script
Using testdata as an example. Edit testdata/run_xander.sh variables SEQFILE, WORKDIR, REF_DIR and JAR_DIR to be the absolute paths, adjust the De Bruijn Graph Build Parameters, especially the FILTER_SIZE for bloom filter size,
```
bash
cd testdata
# edit the run_xander.sh
./run_xander.sh
```

### How to choose the FILTER_SIZE for your dataset?
The size of the bloom filter (or memory needed) is approximately 2^FILTER_SIZE bits. Increase the FILTER_SIZE if the predicted false positive rate (in output file *_bloom_stat.txt) is greater than 1%. Based on our experience with soil metagenome data, FILTER_SIZE 32 (1/2 GB memory) for data size of 2G, 35 (4 GB memory) for data size of 6G, 38 (32 GB memory) for data size of 70G were appropriate. 

### Xander Assembly Steps 

some steps steps can be run in parallel as suggested below
1. Build de Brujin graph
```
* Input: read files
* Output: de Bruijn graph structure
```

2. Identify starting kmers (can be done with multiple genes to save time)
```
* Input 1: A larger set of reference sequences ref_aligned.faa  
* Input 2: read files
* Output: starting nucleotide kmers, alignment positions, HMM states
```

3. Assemble each gene (each gene can be done in parallel)
```
* Input 1: forward and reverse HMMs
* Input 2: de Bruijn graph
* Input 3: starting kmers
* Output: nucleotide and protein contigs
```

4. post-assembly processing
```
* Cluster
* Remove chimeric contigs
* Map reads and kmer abundance
* Find nearest neighbor of the contigs (FrameBot, ProtSeqMatch)
```

## Parameters

### Analysis Parameters
* SEQFILE -- Absolute path to the sequence file (_MUST_ be the absolute path)
* genes -- Genes to assemble (supported out of the box: rplB, nirK, nifH), see Gene Directories
* SAMPLE_SHORTNAME -- a short name for your sample, will be used as prefix of contig IDs (needed when pool contigs from multiple samples)

### DBG Parameters
* MAX_JVM_HEAP -- Maximum amount of memory DBG processes can use (must be larger than FILTER_SIZE below)
* K_SIZE -- K-mer size to assemble at, must be divisible by 3 (recommend 45, minimum 30, maximum 63)
* FILTER_SIZE -- size of the bloom filter, 2**FILTER_SIZE, 38 = 32 gigs, 37 = 16 gigs, 36 = 8 gigs, 35 = 4 gigs, increase FILTER_SIZE if the bloom filter predicted false positive rate is greater than 1%
* MIN_COUNT=1 -- minimum kmer occurrence SEQFILE to be included in the final bloom filter

### Contig Search Parameters
* PRUNE=20 -- prune the search if the score does not improve after n_nodes (default 20, set to -1 to disable pruning)
* PATHS=1 -- number of paths to search for each starting kmer, default 1 returns the shortest path
* LIMIT_IN_SECS=100 -- number of seconds a search allowed for each kmer, recommend 100 secs for 1 shortest path, need to increase if PATHS is greater than 11

### Contig Merge Parameters
* MIN_BITS=50 --mimimum assembled contigs bit score
* MIN_LENGTH=150  -- minimum assembled protein contigs

### Other Paths
* JAR_DIR -- Path to jar files for Xander/ReadSeq/FrameBot/KmerFilter (included in repository)

