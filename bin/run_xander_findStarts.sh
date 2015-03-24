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

## check if the gene directory already exists
genes_to_assembly=( )
for gene in ${genes[*]}
do
    if [ -d "${WORKDIR}/${NAME}/${gene}" ]; then
        echo "DIRECTORY ${WORKDIR}/${NAME}/${gene} EXISTS, SKIPPING (manually delete if you want to rerun) "   
    else
        mkdir ${WORKDIR}/${NAME}/${gene}
        ## add to assembly list
        genes_to_assembly=("${genes_to_assembly[@]}" ${gene})
    fi
done

## if there is no genes in list, exit
if [ ${#genes_to_assembly[@]} -eq 0 ]; then
  exit 0;
fi


## find starting kmers
echo "### Find starting kmers for ${genes_to_assembly[*]}"
genereffiles=
for gene in ${genes_to_assembly[*]}
   do
        genereffiles+="${gene}=${REF_DIR}/gene_resource/${gene}/ref_aligned.faa "
   done

# if there are multiple input seqfiles, do one at a time, This step takes time, recommend run multithreads
temp_order_no=1
for seqfile in ${SEQFILE}
   do
        echo "java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/KmerFilter.jar fast_kmer_filter -a -o temp_starts_${temp_order_no}.txt -t ${THREADS} ${K_SIZE} ${seqfile} ${genereffiles}"
        java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/KmerFilter.jar fast_kmer_filter -a -o temp_starts_${temp_order_no}.txt -t ${THREADS} ${K_SIZE} ${seqfile} ${genereffiles} || { echo "find starting kmers failed" ;  exit 1; }
        ((temp_order_no = $temp_order_no + 1))
   done

## get unique starting kmers
python ${REF_DIR}/pythonscripts/getUniqueStarts.py temp_starts_*.txt > uniq_starts.txt; rm temp_starts_*.txt

## Need to seperate kmers to each gene output directory. This will allow you to run additional genes that were not included in the previous job without waiting for the prevuious assembly to be finished.

for gene in ${genes_to_assembly[*]}
do
        cd ${WORKDIR}/${NAME}/${gene}
        ## the starting kmer might be empty for this gene, continue to next gene
        grep -w "^${gene}" ../uniq_starts.txt > gene_starts.txt || { echo "get uniq starting kmers failed for ${gene}" ; rm gene_starts.txt; continue; }
done


## remove the temporary start kmer files
rm ${WORKDIR}/${NAME}/uniq_starts.txt

