#!/bin/bash -login

## this script builds bloom filter
## this step takes time and requires large memory for large dataset, see Readme for instructions
## not multithreaded yet, wait for future improvement

set -x

#### start of configuration, xander_setenv.sh or qsub_xander_setenv.sh
source $1
#### end of configuration

mkdir -p ${WORKDIR}/${NAME} || { echo "mkdir -p ${WORKDIR}/${NAME} failed"; exit 1;}
cd ${WORKDIR}/${NAME}

## build bloom filter
if [ -f "k${K_SIZE}.bloom" ]; then
  	echo "File k${K_SIZE}.bloom exists, SKIPPING build (manually delete if you want to rerun)"
else
   echo "### Build bloom filter"
   java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar build ${SEQFILE} k${K_SIZE}.bloom ${K_SIZE} ${FILTER_SIZE} ${MIN_COUNT} 4 30 >& k${K_SIZE}_bloom_stat.txt || { echo "build bloom filter failed" ; exit 1; }
fi

