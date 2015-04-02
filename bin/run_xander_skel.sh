#!/bin/bash -login

## This is the main script to run Xander assembly

BASEDIR=/mnt/research/rdp/public/RDPTools/Xander_assembler/bin

if [ $# -ne 3 ]; then
        echo "Requires three inputs : /path/xander_setenv.sh tasks genes"
	echo "  xander_setenv.sh is a file containing the parameter settings, requires absolute path. See example RDPTools/Xander_assembler/bin/xander_setenv.sh"
	echo '  tasks should contain one or more of the following processing steps with quotes around: build find search"'
	echo '  genes should contain one or more genes to process with quotes around'
	echo 'Example command: /path/xander_setenv.sh "build find search" "nifH nirK rplB"'
        exit 1
fi

#### start of configuration
ENVFILE=$1
tasks=$2
genes=$3
source $ENVFILE
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
