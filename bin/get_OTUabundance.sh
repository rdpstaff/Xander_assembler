#!/bin/bash -login
#PBS -A bicep 
#PBS -l walltime=1:00:00,nodes=01:ppn=2,mem=2gb
#PBS -q main
#PBS -M wangqion@msu.edu
#PBS -m abe

#### This script clusters the aligned protein contigs from multiple samples and creates a data matrix file with the OTU abundance at the each distance cutoff
## Input 1: a contig coverage file (used to adjust the sequence abundance)
## Input 2: output directory
## Input 2: start and end distance cutoff
## Input 4: takes the aligned protein contig files (_final_prot_aligned.fasta), must be from the same gene 
## Output: one data matrix containing the OTU abundance at the each distance cutoff

## THIS MUST BE MODIFIED TO YOUR FILE SYSTEM
## must be absolute path
JAR_DIR=/mnt/research/rdp/private/Qiong_xander_analysis/RDPTools/
MAX_JVM_HEAP=2G # memory for java program

if [ $# -lt 5 ]; then
        echo Usage: coverage_file outdir start_dist end_dist aligned_files
	echo start_dist and end_dist must be in the range [0, 0.5]
        exit 1
fi


## aligned_files can use wildcards to point to multiple files (fasta, fataq or gz format), as long as there are no spaces in the names 
coverage_file=$1
outdir=$2
start_dist=$3  # range 0 to 0.5 
end_dist=$4	# range 0 to 0.5 


((len=$# -4))
aligned_files=("${*:5:${len}}")

# cluster
java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/Clustering.jar derep -o derep.fa -m '#=GC_RF' ids samples ${aligned_files} || { echo "derep failed" ;  exit 1; }

java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/Clustering.jar dmatrix  -c 0.5 -I derep.fa -i ids -l 50 -o dmatrix.bin || { echo "dmatrix failed" ;  exit 1; }

java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/Clustering.jar cluster -d dmatrix.bin -i ids -s samples -o complete.clust || { echo "cluster failed" ;  exit 1; }

rm dmatrix.bin nonoverlapping.bin

# get coverage-adjusted OTU matrix file
java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/Clustering.jar cluster_to_Rformat complete.clust ${outdir} ${start_dist} ${end_dist} ${coverage_file}

# PCA, NMDS plots using vegan package in R
