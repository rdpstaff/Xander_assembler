#!/bin/bash -login
#PBS -A bicep
#PBS -l walltime=5:00:00,nodes=01:ppn=2,mem=2gb
#PBS -q main
#PBS -M wangqion@msu.edu
#PBS -m abe

##### EXAMPLE: qsub command on MSU HPCC
# qsub -l walltime=1:00:00,nodes=01:ppn=2,mem=2GB -v MAX_JVM_HEAP=2G,FILTER_SIZE=32,K_SIZE=45,genes="nifH nirK rplB amoA_AOA",THREADS=1,SAMPLE_SHORTNAME=test,WORKDIR=/PATH/testdata/,SEQFILE=/PATH/testdata/test_reads.fa qsub_run_xander.sh

#### start of configuration

###### Adjust values for these parameters ####
#       SEQFILE, genes, SAMPLE_SHORTNAME
#       WORKDIR, REF_DIR, JAR_DIR, UCHIME, HMMALIGN
#       FILTER_SIZE, MAX_JVM_HEAP, K_SIZE
#       THREADS, ppn
#####################

## THIS SECTION MUST BE MODIFIED FOR YOUR FILE SYSTEM. MUST BE ABSOLUTE PATH
## SEQFILE can use wildcards to point to multiple files (fasta, fataq or gz format), as long as there are no spaces in the names
SEQFILE=/mnt/research/rdp/public/RDPTools/Xander_assembler/testdata/test_reads.fa
WORKDIR=/mnt/research/rdp/public/RDPTools/Xander_assembler/testdata
REF_DIR=/mnt/research/rdp/public/RDPTools/Xander_assembler
JAR_DIR=/mnt/research/rdp/public/RDPTools/
UCHIME=/mnt/research/rdp/public/thirdParty/uchime-4.2.40/uchime
HMMALIGN=/opt/software/HMMER/3.1b1--GCC-4.4.5/bin/hmmalign


## THIS SECTION NEED TO BE MODIFIED FOR GENES INTERESTED, and SAMPLE_SHORTNAME WILL BE THE PREFIX OF CONTIG ID
genes=(nifH nirK rplB amoA_AOB amoA_AOA nirS nosZ)
SAMPLE_SHORTNAME=test

## THIS SECTION MUST BE MODIFIED BASED ON THE INPUT DATASETS
## De Bruijn Graph Build Parameters
K_SIZE=45  # kmer size, should be multiple of 3
FILTER_SIZE=32 # memory = 2**FILTER_SIZE, 38 = 32 GB, 37 = 16 GB, 36 = 8 GB, 35 = 4 GB, increase FILTER_SIZE if the bloom filter predicted false positive rate is greater than 1%
MAX_JVM_HEAP=2G # memory for java program, must be larger than the corresponding memory of the FILTER_SIZE
MIN_COUNT=1  # minimum kmer abundance in SEQFILE to be included in the final de Bruijn graph structure

## ppn should be THREADS +1
THREADS=1

## Contig Search Parameters
PRUNE=20 # prune the search if the score does not improve after n_nodes (default 20, set to -1 to disable pruning)
PATHS=1 # number of paths to search for each starting kmer, default 1 returns the shortest path
LIMIT_IN_SECS=100 # number of seconds a search allowed for each kmer, recommend 100 secs if PATHS is 1, need to increase if PATHS is large 

## Contig Merge Parameters
MIN_BITS=50  # mimimum assembled contigs bit score
MIN_LENGTH=100  # minimum assembled protein contigs

## Contig Clustering Parameters
DIST_CUTOFF=0.01  # cluster at aa distance 

NAME=k${K_SIZE}

#### end of configuration

mkdir -p ${WORKDIR}/${NAME} || { echo "mkdir -p ${WORKDIR}/${NAME} failed"; exit 1;}
cd ${WORKDIR}/${NAME}

## build bloom filter, this step takes time, not multithreaded yet, wait for future improvement
if [ -f "k${K_SIZE}.bloom" ]; then
  	echo "File k${K_SIZE}.bloom exists"
else
   echo "### Build bloom filter"
   echo "java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar build ${SEQFILE} k${K_SIZE}.bloom ${K_SIZE} ${FILTER_SIZE} ${MIN_COUNT} 4 30 >& k${K_SIZE}_bloom_stat.txt"
   java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar build ${SEQFILE} k${K_SIZE}.bloom ${K_SIZE} ${FILTER_SIZE} ${MIN_COUNT} 4 30 >& k${K_SIZE}_bloom_stat.txt || { echo "build bloom filter failed" ; exit 1; }
fi


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
        genereffiles+="${gene}=${REF_DIR}/${gene}/ref_aligned.faa "
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


## remove the start kmer files
rm ${WORKDIR}/${NAME}/uniq_starts.txt

## search contigs
for gene in ${genes_to_assembly[*]}
do
	cd ${WORKDIR}/${NAME}/${gene}
	## the starting kmer might be empty for this gene, continue to next gene
	if [ ! -s gene_starts.txt ]; then
		continue;
	fi
	echo "### Search contigs ${gene}"
	echo "java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar search -p ${PRUNE} ${PATHS} ${LIMIT_IN_SECS} ../k${K_SIZE}.bloom ${REF_DIR}/${gene}/for_enone.hmm ${REF_DIR}/${gene}/rev_enone.hmm gene_starts.txt 1> stdout.txt 2> stdlog.txt"
	java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar search -p ${PRUNE} ${PATHS} ${LIMIT_IN_SECS} ../k${K_SIZE}.bloom ${REF_DIR}/${gene}/for_enone.hmm ${REF_DIR}/${gene}/rev_enone.hmm gene_starts.txt 1> stdout.txt 2> stdlog.txt || { echo "search contigs failed for ${gene}" ; exit 1; }

	## merge contigs 
	if [ ! -s gene_starts.txt_nucl.fasta ]; then
           continue;
        fi
	echo "### Merge contigs"
	## define the prefix for the output file names
	fileprefix=${SAMPLE_SHORTNAME}_${gene}_${K_SIZE}
	echo "java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar merge -a -o merge_stdout.txt -s ${SAMPLE_SHORTNAME} -b ${MIN_BITS} --min-length ${MIN_LENGTH} ${REF_DIR}/${gene}/for_enone.hmm stdout.txt gene_starts.txt_nucl.fasta"
	java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar merge -a -o merge_stdout.txt -s ${SAMPLE_SHORTNAME} -b ${MIN_BITS} --min-length ${MIN_LENGTH} ${REF_DIR}/${gene}/for_enone.hmm stdout.txt gene_starts.txt_nucl.fasta || { echo "merge contigs failed for ${gene}" ; exit 1;}

	## get the unique merged contigs
	if [ ! -s prot_merged.fasta ]; then
           continue;
        fi
	java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/Clustering.jar derep -o temp_prot_derep.fa  ids samples prot_merged.fasta || { echo "get unique contigs failed for ${gene}" ; continue; }
        java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/ReadSeq.jar rm-dupseq -d -i temp_prot_derep.fa -o ${fileprefix}_prot_merged_rmdup.fasta || { echo "get unique contigs failed for ${gene}" ; continue; }
        rm prot_merged.fasta temp_prot_derep.fa ids samples

	## cluster at 99% aa identity
	echo "### Cluster"
	mkdir -p cluster
	cd cluster
	mkdir -p alignment

	## prot_merged.fasta might be empty, continue to next gene
	## if use HMMER3.0, need --allcol option ##
	${HMMALIGN} -o alignment/aligned.stk ${REF_DIR}/${gene}/originaldata/${gene}.hmm ../${fileprefix}_prot_merged_rmdup.fasta || { echo "hmmalign failed" ;  continue; }

	java -Xmx2g -jar ${JAR_DIR}/AlignmentTools.jar alignment-merger alignment aligned.fasta || { echo "alignment merger failed" ;  exit 1; }

	java -Xmx2g -jar ${JAR_DIR}/Clustering.jar derep -o derep.fa -m '#=GC_RF' ids samples aligned.fasta || { echo "derep failed" ;  exit 1; }

	## if there is no overlap between the contigs, mcClust will throw errors, we should use the ../prot_merged_rmdup.fasta as  prot_rep_seqs.fasta 
	java -Xmx2g -jar ${JAR_DIR}/Clustering.jar dmatrix  -c 0.5 -I derep.fa -i ids -l 25 -o dmatrix.bin || { echo "dmatrix failed, continue with ${fileprefix}_prot_merged_rmdup.fasta" ; cp ../${fileprefix}_prot_merged_rmdup.fasta ${fileprefix}_prot_rep_seqs.fasta ; }

	if [ -s dmatrix.bin ]; then
		java -Xmx2g -jar ${JAR_DIR}/Clustering.jar cluster -d dmatrix.bin -i ids -s samples -o complete.clust || { echo "cluster failed" ;  exit 1; }

        	# get representative seqs
        	java -Xmx2g -jar ${JAR_DIR}/Clustering.jar rep-seqs -l -s complete.clust ${DIST_CUTOFF} aligned.fasta || { echo " rep-seqs failed" ;  exit 1; }
        	java -Xmx2g -jar ${JAR_DIR}/Clustering.jar to-unaligned-fasta complete.clust_rep_seqs.fasta > ${fileprefix}_prot_rep_seqs.fasta || { echo " to-unaligned-fasta failed" ;  exit 1; }
		rm dmatrix.bin complete.clust_rep_seqs.fasta
        fi


	grep '>' ${fileprefix}_prot_rep_seqs.fasta |cut -f1 | cut -f1 -d ' ' | sed -e 's/>//' > id || { echo " failed" ;  exit 1; }
	java -Xmx2g -jar ${JAR_DIR}/ReadSeq.jar select-seqs id ${fileprefix}_nucl_rep_seqs.fasta fasta Y ../nucl_merged.fasta || { echo " filter-seqs failed" ;  exit 1; }

	rm -r derep.fa nonoverlapping.bin alignment samples ids id

	echo "### Chimera removal"
	# remove chimeras and obtain the final good set of nucleotide and protein contigs
        ${UCHIME} --input ${fileprefix}_nucl_rep_seqs.fasta --db ${REF_DIR}/${gene}/originaldata/nucl.fa --uchimeout results.uchime.txt -uchimealns result_uchimealn.txt || { echo "chimera check failed" ;  continue; }
        egrep '\?$|Y$' results.uchime.txt | cut -f2 | cut -f1 -d ' ' | cut -f1 > chimera.id || { echo " egrep failed" ;  exit 1; }
	java -Xmx2g -jar ${JAR_DIR}/ReadSeq.jar select-seqs chimera.id ${fileprefix}_final_nucl.fasta fasta N ${fileprefix}_nucl_rep_seqs.fasta || { echo " select-seqs ${fileprefix}_nucl_rep_seqs.fasta failed" ; exit 1; }

        grep '>' ${fileprefix}_final_nucl.fasta | sed -e 's/>//' > id; java -Xmx2g -jar ${JAR_DIR}/ReadSeq.jar select-seqs id ${fileprefix}_final_prot.fasta fasta Y ../${fileprefix}_prot_merged_rmdup.fasta;  echo '#=GC_RF' >> id; java -Xmx2g -jar ${JAR_DIR}/ReadSeq.jar select-seqs id ${fileprefix}_final_prot_aligned.fasta fasta Y aligned.fasta ; rm id || { echo " select-seqs failed" ; rm id; exit 1; }

	if [ ! -f ${fileprefix}_final_nucl.fasta  ]; then
                continue;
        fi

        ## find the closest matches of the nucleotide representatives using FrameBot
	echo "### FrameBot"
        echo "java -jar ${JAR_DIR}/FrameBot.jar framebot -N -l ${MIN_LENGTH} -o ${gene}_${K_SIZE} ${REF_DIR}/${gene}/originaldata/framebot.fa nucl_rep_seqs_rmchimera.fasta"
        java -jar ${JAR_DIR}/FrameBot.jar framebot -N -l ${MIN_LENGTH} -o ${fileprefix} ${REF_DIR}/${gene}/originaldata/framebot.fa ${fileprefix}_final_nucl.fasta || { echo "FrameBot failed for ${gene}" ; continue; }

	## or find the closest matches of protein representatives final_prot.fasta using AlignmentTool pairwise-knn

	## find kmer coverage of the representative seqs, this step takes time, recommend to run multiplethreads
	echo "### Kmer abundance"
        echo "java -Xmx2g -jar ${JAR_DIR}/KmerFilter.jar kmer_coverage -t ${THREADS} -m ${fileprefix}_match_reads.fa ${K_SIZE} ${fileprefix}_final_nucl.fasta ${fileprefix}_coverage.txt ${fileprefix}_abundance.txt ${SEQFILE}"
        java -Xmx2g -jar ${JAR_DIR}/KmerFilter.jar kmer_coverage -t ${THREADS} -m ${fileprefix}_match_reads.fa ${K_SIZE} ${fileprefix}_final_nucl.fasta ${fileprefix}_coverage.txt ${fileprefix}_abundance.txt ${SEQFILE} || { echo "kmer_coverage failed" ;  continue; }

	## get the taxonomic abundance, use the lineage from the protein reference file
	java -Xmx2g -jar ${JAR_DIR}/FrameBot.jar taxonAbund -c ${fileprefix}_coverage.txt ${fileprefix}_framebot.txt ${REF_DIR}/${gene}/originaldata/framebot.fa ${fileprefix}_taxonabund.txt


done


