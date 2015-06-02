#!/bin/bash -login
#PBS -l walltime=5:00:00,nodes=01:ppn=2,mem=2gb
#PBS -q main
#PBS -M wangqion@msu.edu
#PBS -m abe

##### EXAMPLE qsub command on MSU HPCC
#### WORKDIR, ENVFILE and SEQFILE must be the absolute paths
# qsub -l walltime=1:00:00,nodes=01:ppn=2,mem=2GB -v MAX_JVM_HEAP=2G,FILTER_SIZE=32,K_SIZE=45,MIN_COUNT=2,tasks="build find search",genes="nifH nirK rplB amoA_AOA",THREADS=1,SAMPLE_SHORTNAME=test,WORKDIR=/PATH/testdata/,ENVFILE=/PATH/qsub_xander_setenv.sh,SEQFILE=/PATH/testdata/test_reads.fa qsub_run_xander.sh

BASEDIR=/mnt/research/rdp/public/RDPTools/Xander_assembler/bin/

#### start of configuration
source ${ENVFILE}
#### end of configuration

## build bloom filter, this step takes time, not multithreaded yet, wait for future improvement
## only once for each dataset at given kmer length
if [[ " ${tasks[*]} " == *"build"* ]]; then
        $BASEDIR/run_xander_build.sh $ENVFILE || { exit 1; }
fi

## find starting kmers, multiple genes should be run together to save time, has multithread option
if [[ " ${tasks[*]} " == *"find"* ]]; then
        $BASEDIR/run_xander_findStarts.sh $ENVFILE "$genes" || { exit 1; }
fi

## search contigs and post-assembly processing
## can run in parallel 
if [[ " ${tasks[*]} " == *"search"* ]]; then
	for gene in ${genes[*]}
	do
        	$BASEDIR/run_xander_search.sh $ENVFILE "${gene}"
	done
fi
