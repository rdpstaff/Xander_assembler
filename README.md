# Xander Gene_targeted Assember analysis pipeline

### Required tools

* Python 2.7+
* Java 1.6+
* HMMER 3.0 (If using 3.1+ remove --allcol from gene.Makefile)
* GNU Make (optional)

## Per Gene Preparation:
    Reference Set Selection - Select a set of reference sequences (resouce: http://fungene.cme.msu.edu/) representative of the gene of interest.  More diversity is better, more sequences means more starting points (more computational time) but less suceptiable to noise than model creation.
    Model Construction - HMMs can be built using HMMER3 (models are expected to be in HMMER3/b format).  A forward and reverse model (left and right) must be built.  The reverse model is built simply by reversing the seed alignment (using script pythonscripts/reverse.py) and running hmmbuild again.

## Gene Analysis Directories

Reference sequence files and models for each gene targeted for assembly are placed in a directory in the main analysis directory.  Included with the skeleton analysis pipeline are configurations for assembling rplB, nirK, and nifH genes.

A gene analysis directory must contain two hidden markov models built with HMMER3 named for_enone.hmm and rev_enone.hmm for the forward and reverse of the gene sequences respectively.  Also a ref_aligned.faa file must contain a set of protein reference sequences aligned with for_enone.hmm.  This file is used to identify starting kmers for assembly. 
A file framebot.fa containing a set of protein reference sequences in the directory originaldata of each gene is also need for FrameBot to find the nearest matches for the assembled contigs.

The analysis pipeline will attempt to assemble all genes specified in the bin/run_xander_skel.sh or Makefile variable 'genes' (see below), which requires a directory for each gene name with the above structure.  See the existing rplb/nirk/nifh directories for further examples.

## Analysis

### Quickstart using shell script
Using testdata as an example. Copy and edit bin/run_xander_skel.sh variables SEQFILE, WORKDIR, REF_DIR and JAR_DIR to be the absolute paths, adjust the De Bruijn Graph Build Parameters, especially the FILTER_SIZE for bloom filter size,
```
bash
cd testdata
cp ../bin/run_xander_skel.sh run_xander.sh
# edit the run_xander.sh
./run_xander.sh
```

### How to choose the FILTER_SIZE for your dataset?
The size of the bloom filter (or memory needed) is approximately 2^FILTER_SIZE bits. Increase the FILTER_SIZE if the predicted false positive rate (in output file *_bloom_stat.txt) is greater than 1%. Based on our experience with soil metagenome data, FILTER_SIZE 32 (1/2 GB memory) for data size of 2G, 35 (4 GB memory) for data size of 6G, 38 (32 GB memory) for data size of 70G were appropriate. 

### Suggested Workflow if using Makefile

While you can type 
```
bash
cp Makefile_skel Makefile
```

some steps steps can be run in parallel as suggested below

1. 
    a. Building the bloom filter (once per dataset)
```
	bash
	make bloom
```

    b. Identify assembly starting kmers (can be done with multiple genes with bloom filter generation),
```
	bash
	make uniq_starts
```

2. Assemble each gene (each gene can be done in parallel)
```
bash
make <gene_name>
```


## Parameters

### Analysis Parameters
* SEQFILE -- Absolute path to the sequence file (_MUST_ be the absolute path)
* genes -- Genes to assemble (supported out of the box: rplB, nirK, nifH), see Gene Directories

### DBG Parameters
* MAX_JVM_HEAP -- Maximum amount of memory DBG processes can use (must be larger than FILTER_SIZE below)
* K_SIZE -- K-mer size to assemble at, must be divisible by 3 (recommend 45, minimum 30, maximum 63)
* FILTER_SIZE -- size of the bloom filter, 2**FILTER_SIZE, 38 = 32 gigs, 37 = 16 gigs, 36 = 8 gigs, 35 = 4 gigs, increase FILTER_SIZE if the bloom filter predicted false positive rate is greater than 1%
* MIN_COUNT=1 -- minimum kmer occurrence SEQFILE to be included in the final bloom filter

### Contig Search Parameters
* PRUNE=20 -- maximum number of consecutive decreases in scores before being pruned, -1 means no pruning, recommended 20 for large dataset
* PATHS=1 -- number of paths to search for each starting kmer, default 1 returns the shortest path
* LIMIT_IN_SECS=100 -- number of seconds a search allowed for each kmer, recommend 100 secs for 1 shortest path, need to increase if PATHS is greater than 11

### Contig Filtering Parameters
MIN_BITS=50 --mimimum assembled contigs bit score
MIN_LENGTH=150  -- minimum assembled protein contigs

### Other Paths
* JAR_DIR -- Path to jar files for Xander/ReadSeq/FrameBot/KmerFilter (included in repository)

