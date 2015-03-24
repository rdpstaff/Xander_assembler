#!/bin/bash -login
#PBS -A bicep
#PBS -l walltime=5:00:00,nodes=01:ppn=2,mem=2gb
#PBS -q main
#PBS -M wangqion@msu.edu
#PBS -m abe

##### EXAMPLE: qsub command on MSU HPCC
# qsub -l walltime=1:00:00,nodes=01:ppn=2,mem=2GB -v MAX_JVM_HEAP=2G,FILTER_SIZE=32,K_SIZE=45,genes="nifH nirK rplB amoA_AOA",THREADS=1,SAMPLE_SHORTNAME=test,WORKDIR=/PATH/testdata/,SEQFILE=/PATH/testdata/test_reads.fa qsub_run_xander.sh

BASEDIR=/mnt/research/rdp/public/RDPTools/Xander_assembler/bin

#### start of configuration
source $BASEDIR/xander_setenv.sh
#### end of configuration

## build bloom filter, this step takes time, not multithreaded yet, wait for future improvement
## only once for each dataset at given kmer length
$BASEDIR/run_xander_build.sh $BASEDIR/xander_setenv.sh

## find starting kmers, multiple genes should be run together to save time, has multithread option
$BASEDIR/run_xander_findStarts.sh $BASEDIR/xander_setenv.sh

## search contigs and post-assembly processing
## can run in parallel 

for gene in ${genes[*]}
do
	echo "$BASEDIR/run_xander_search.sh $BASEDIR/xander_setenv.sh ${gene}"
	$BASEDIR/run_xander_search.sh $BASEDIR/xander_setenv.sh ${gene}  
done
