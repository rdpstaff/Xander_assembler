#!/bin/bash -login

## This script runs contigs search and post-assembly processing
## The search step requires large memory for large dataset, see Readme for instructions
## This step assumes a gene directory already exists with gene_start.txt in the directory for each gene in the genes list
## This will overwrites the previous search and post-assembly results

if [ $# -ne 2 ]; then
        echo "Requires two inputs : /path/xander_setenv.sh genes"
        echo "  xander_setenv.sh is a file containing the parameter settings, requires absolute path. see example RDPTools/Xander_assembler/bin/xander_setenv.sh"
        echo '  genes should contain one or more genes to process with quotes around'
        echo 'Example command: /path/xander_setenv.sh "nifH nirK rplB"'
        exit 1
fi

set -x

#### start of configuration, xander_setenv.sh or qsub_xander_setenv.sh
source $1
genes=$2
#### end of configuration


## search contigs
for gene in ${genes}
do
	cd ${WORKDIR}/${NAME}/${gene}
	## the starting kmer might be empty for this gene, continue to next gene
	if [ ! -s gene_starts.txt ]; then
		continue;
	fi
	echo "### Search contigs ${gene}"
	java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar search -p ${PRUNE} ${PATHS} ${LIMIT_IN_SECS} ../k${K_SIZE}.bloom ${REF_DIR}/gene_resource/${gene}/for_enone.hmm ${REF_DIR}/gene_resource/${gene}/rev_enone.hmm gene_starts.txt 1> stdout.txt 2> stdlog.txt || { echo "search contigs failed for ${gene}" ; exit 1; }

	## merge contigs 
	if [ ! -s gene_starts.txt_nucl.fasta ]; then
           continue;
        fi
	echo "### Merge contigs"
	## define the prefix for the output file names
	fileprefix=${SAMPLE_SHORTNAME}_${gene}_${K_SIZE}
	java -Xmx${MAX_JVM_HEAP} -jar ${JAR_DIR}/hmmgs.jar merge -a -o merge_stdout.txt -s ${SAMPLE_SHORTNAME} -b ${MIN_BITS} --min-length ${MIN_LENGTH} ${REF_DIR}/gene_resource/${gene}/for_enone.hmm stdout.txt gene_starts.txt_nucl.fasta || { echo "merge contigs failed for ${gene}" ; exit 1;}

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
	${HMMALIGN} -o alignment/aligned.stk ${REF_DIR}/gene_resource/${gene}/originaldata/${gene}.hmm ../${fileprefix}_prot_merged_rmdup.fasta || { echo "hmmalign failed" ;  continue; }

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
        ${UCHIME} --input ${fileprefix}_nucl_rep_seqs.fasta --db ${REF_DIR}/gene_resource/${gene}/originaldata/nucl.fa --uchimeout results.uchime.txt -uchimealns result_uchimealn.txt || { echo "chimera check failed" ;  continue; }
        egrep '\?$|Y$' results.uchime.txt | cut -f2 | cut -f1 -d ' ' | cut -f1 > chimera.id || { echo " egrep failed" ;  exit 1; }
	java -Xmx2g -jar ${JAR_DIR}/ReadSeq.jar select-seqs chimera.id ${fileprefix}_final_nucl.fasta fasta N ${fileprefix}_nucl_rep_seqs.fasta || { echo " select-seqs ${fileprefix}_nucl_rep_seqs.fasta failed" ; exit 1; }

        grep '>' ${fileprefix}_final_nucl.fasta | sed -e 's/>//' > id; java -Xmx2g -jar ${JAR_DIR}/ReadSeq.jar select-seqs id ${fileprefix}_final_prot.fasta fasta Y ../${fileprefix}_prot_merged_rmdup.fasta;  echo '#=GC_RF' >> id; java -Xmx2g -jar ${JAR_DIR}/ReadSeq.jar select-seqs id ${fileprefix}_final_prot_aligned.fasta fasta Y aligned.fasta ; rm id || { echo " select-seqs failed" ; rm id; exit 1; }

	if [ ! -f ${fileprefix}_final_nucl.fasta  ]; then
                continue;
        fi

        ## find the closest matches of the nucleotide representatives using FrameBot
	echo "### FrameBot"
        java -jar ${JAR_DIR}/FrameBot.jar framebot -N -l ${MIN_LENGTH} -o ${fileprefix} ${REF_DIR}/gene_resource/${gene}/originaldata/framebot.fa ${fileprefix}_final_nucl.fasta || { echo "FrameBot failed for ${gene}" ; continue; }

	## or find the closest matches of protein representatives final_prot.fasta using AlignmentTool pairwise-knn

	## find kmer coverage of the representative seqs, this step takes time, recommend to run multiplethreads
	echo "### Kmer abundance"
        java -Xmx2g -jar ${JAR_DIR}/KmerFilter.jar kmer_coverage -t ${THREADS} -m ${fileprefix}_match_reads.fa ${K_SIZE} ${fileprefix}_final_nucl.fasta ${fileprefix}_coverage.txt ${fileprefix}_abundance.txt ${SEQFILE} || { echo "kmer_coverage failed" ;  continue; }

	## get the taxonomic abundance, use the lineage from the protein reference file
	java -Xmx2g -jar ${JAR_DIR}/FrameBot.jar taxonAbund -c ${fileprefix}_coverage.txt ${fileprefix}_framebot.txt ${REF_DIR}/gene_resource/${gene}/originaldata/framebot.fa ${fileprefix}_taxonabund.txt


done


