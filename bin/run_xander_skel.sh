#!/bin/bash -login

#### start of configuration

# must be absolute path
SEQFILE=/realpath/myreads.fasta
WORKDIR=/realpath/output_dir/
REF_DIR=/realpath/Xander_assembler/
JAR_DIR=/realpath/RDPTools/
genes=(nifh nirk rplb)

# De Bruijn Graph Build Parameters
MAX_JVM_HEAP=8G # memory for java program
K_SIZE=45  # kmer size, should be multiple of 3
FILTER_SIZE=35 # 2**FILTER_SIZE, 38 = 32 gigs, 37 = 16 gigs, 36 = 8 gigs, 35 = 4 gigs, increase FILTER_SIZE if the bloom filter predicted false positive rate is greater than 1%
MIN_COUNT=1  # minimum kmer occurrence SEQFILE to be included in the final bloom filter

# Contig Search Parameters
PRUNE=20 # maximum number of consecutive decreases in scores before being pruned, -1 means no pruning, recommended 20 for large dataset
PATHS=1 # number of paths to search for each starting kmer, default 1 returns the shortest path
LIMIT_IN_SECS=100 # number of seconds a search allowed for each kmer, recommend 100 secs for 1 shortest path, need to increase if PATHS is greater than 11

# Contig Filtering Parameters
MIN_BITS=50  # mimimum assembled contigs bit score
MIN_LENGTH=150  # minimum assembled protein contigs

NAME=k${K_SIZE}

#### end of configuration

mkdir -p ${WORKDIR}/${NAME}
cd ${WORKDIR}/${NAME}

## build bloom filter
if [ -f "k${K_SIZE}.bloom" ] && [ k${K_SIZE}.bloom -nt ${SEQFILE} ];
then
  	echo "File k${K_SIZE}.bloom exists"
else
   echo "Build bloom filter"
   echo "java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar build ${SEQFILE} k${K_SIZE}.bloom ${K_SIZE} ${FILTER_SIZE} ${MIN_COUNT} 4 30 >& k${K_SIZE}_bloom_stat.txt"
   java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar build ${SEQFILE} k${K_SIZE}.bloom ${K_SIZE} ${FILTER_SIZE} ${MIN_COUNT} 4 30 >& k${K_SIZE}_bloom_stat.txt || { echo 'build bloom filter failed' ; exit 1; }
fi

## find starting kmers
if [ -f "starts.txt" ] && [ starts.txt -nt k${K_SIZE}.bloom ];
then
   echo "File starts.txt exists"
else
   echo "find starting kmers for ${genes[*]}"
genereffiles=
for gene in ${genes[*]}
do 
	genereffiles+="${gene}=${REF_DIR}/${gene}/ref_aligned.faa "
done
echo "java -jar ${JAR_DIR}/KmerFilter.jar fast_kmer_filter -a -o starts.txt -t 1 ${K_SIZE} ${SEQFILE} ${genereffiles}"
java -jar ${JAR_DIR}/KmerFilter.jar fast_kmer_filter -a -o starts.txt -t 1 ${K_SIZE} ${SEQFILE} ${genereffiles} || { echo 'find staring kmers failed' ; exit 1; }
fi

## get unique starging kmers
python ${REF_DIR}/pythonscripts/getUniqueStarts.py starts.txt > uniq_starts.txt

## search contigs
for gene in ${genes[*]}
do
	mkdir -p ${WORKDIR}/${NAME}/${gene}
	cd ${WORKDIR}/${NAME}/${gene}
	grep ${gene} ../uniq_starts.txt > gene_starts.txt || { echo 'get uniq starting kmers failed for ${gene}' ; exit 1; }
	echo "search contigs ${gene}"
	echo "java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar search -p ${PRUNE} ${PATHS} ${LIMIT_IN_SECS} ../k${K_SIZE}.bloom ${REF_DIR}/${gene}/for_enone.hmm ${REF_DIR}/${gene}/rev_enone.hmm gene_starts.txt 1> stdout.txt 2> stdlog.txt"
	java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar search -p ${PRUNE} ${PATHS} ${LIMIT_IN_SECS} ../k${K_SIZE}.bloom ${REF_DIR}/${gene}/for_enone.hmm ${REF_DIR}/${gene}/rev_enone.hmm gene_starts.txt 1> stdout.txt 2> stdlog.txt || { echo 'search contigs failed for ${gene}' ; exit 1; }

	## merge contigs 
	echo "merge contigs"
	echo "java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar merge -a -b ${MIN_BITS} --min-length ${MIN_LENGTH} ${REF_DIR}/${gene}/for_enone.hmm stdout.txt gene_starts.txt_nucl.fasta"
	java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar merge -a -b ${MIN_BITS} --min-length ${MIN_LENGTH} ${REF_DIR}/${gene}/for_enone.hmm stdout.txt gene_starts.txt_nucl.fasta || { echo 'merge contigs failed for ${gene}' ; exit 1; }

	## get the unique merged contigs
	echo "java -Xmx2g -jar ${JAR_DIR}/Clustering.jar derep -u -o nucl_merged_derep.fasta ids samples nucl_merged.fasta"
	java -Xmx2g -jar ${JAR_DIR}/Clustering.jar derep -u -o nucl_merged_derep.fasta ids samples nucl_merged.fasta || { echo 'get unique contigs failed for ${gene}' ; exit 1; }
	java -Xmx2g -jar ${JAR_DIR}/Clustering.jar derep -u -o prot_merged_derep.fasta ids samples prot_merged.fasta || { echo 'get unique contigs failed for ${gene}' ; exit 1; }

	## find the closest matches using FrameBot
	echo "java -jar ${JAR_DIR}/FrameBot.jar framebot -N -l ${MIN_LENGTH} -o ${gene}_${K_SIZE} ${REF_DIR}/${gene}/originaldata/framebot.fa nucl_merged_derep.fasta"
	java -jar ${JAR_DIR}/FrameBot.jar framebot -N -l ${MIN_LENGTH} -o ${gene}_${K_SIZE} ${REF_DIR}/${gene}/originaldata/framebot.fa nucl_merged_derep.fasta || { echo 'FrameBot failed for ${gene}' ; exit 1; }
done

