#!/bin/bash -login
#PBS -A bicep
#PBS -l walltime=5:00:00,nodes=01:ppn=2,mem=2gb
#PBS -q main
#PBS -M wangqion@msu.edu
#PBS -m abe

##### EXAMPLE: qsub command on MSU HPCC
# qsub -l walltime=1:00:00,nodes=01:ppn=2,mem=2GB -v MAX_JVM_HEAP=2G,FILTER_SIZE=32,K_SIZE=45,genes="nifH nirK rplB amoA_AOA",THREADS=1,SAMPLE_SHORTNAME=test,WORKDIR=/PATH/testdata/,SEQFILE=/PATH/testdata/test_reads.fa qsub_run_xander.sh

#### start of configuration, xander_setenv.sh or qsub_xander_setenv.sh
source $1
#### end of configuration

mkdir -p ${WORKDIR}/${NAME} || { echo "mkdir -p ${WORKDIR}/${NAME} failed"; exit 1;}
cd ${WORKDIR}/${NAME}

## build bloom filter, this step takes time, not multithreaded yet, wait for future improvement
if [ -f "k${K_SIZE}.bloom" ]; then
  	echo "File k${K_SIZE}.bloom exists, SKIPPING (manually delete if you want to rerun)"
else
   echo "### Build bloom filter"
   echo "java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar build ${SEQFILE} k${K_SIZE}.bloom ${K_SIZE} ${FILTER_SIZE} ${MIN_COUNT} 4 30 >& k${K_SIZE}_bloom_stat.txt"
   java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar build ${SEQFILE} k${K_SIZE}.bloom ${K_SIZE} ${FILTER_SIZE} ${MIN_COUNT} 4 30 >& k${K_SIZE}_bloom_stat.txt || { echo "build bloom filter failed" ; exit 1; }
fi

