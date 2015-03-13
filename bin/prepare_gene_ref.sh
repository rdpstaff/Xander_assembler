#!/bin/bash -login

if [ $# -ne 1 ]; then
        echo Usage: gene 
        exit 1
fi

## THIS MUST BE MODIFIED TO YOUR FILE SYSTEM
JAR_DIR=/mnt/research/rdp/public/RDPTools/
REF_DIR=/mnt/research/rdp/public/RDPTools/Xander_assembler/

## NOTE you need to used the modified hmmer-3.0_xanderpatch to build the specialized forward and reverse HMMs for Xander 
hmmer_xanderpatch=/mnt/research/rdp/public/thirdParty/hmmer-3.0_xanderpatch/

gene=$1

## REQUIRED FILES 
# This directory must exists:  RDPTools/Xander_assembler/gene/originaldata 
# In the originaldata directory, you need these files (from FunGene site with option Minimum HMM Coverage at least 80 (%)):
# gene.seeds: small set of protein sequences in FASTA format, used to build forward and reverse HMMs
# gene.hmm: this is the HMM built from gene.seeds using original HMMER3. This will be used to build for_enone.hmm and align contigs after assembly 
# nucl.fa: a large near full length known set used by UCHIME chimera check step
# framebot.fa: a large near full length known protein set to be used to create starting kmers and FrameBot 

## OUTPUTS
## This script will create three files to dir RDPTools/Xander_assembler/gene/:
## for_enone.hmm and rev_enone.hmm that will be used by Xander search step.
## ref_aligned.faa will be used by Xander find starting kmer step


cd ${REF_DIR}/gene_resource/${gene}/originaldata || { echo " directory not found" ;  exit 1; }

## create forward and reverse hmms for Xander.
${hmmer_xanderpatch}/src/hmmalign --allcol -o ${gene}_seeds_aligned.stk ${gene}.hmm ${gene}.seeds
${hmmer_xanderpatch}/src/hmmbuild --enone ../for_enone.hmm ${gene}_seeds_aligned.stk

java -jar ${JAR_DIR}/ReadSeq.jar to-fasta ${gene}_seeds_aligned.stk > ${gene}_seeds_aligned.fasta

python ${JAR_DIR}/Xander_assembler/pythonscripts/reverse.py ${gene}_seeds_aligned.fasta
java -jar ${JAR_DIR}/ReadSeq.jar to-stk -r rev_${gene}_seeds_aligned.fasta rev_${gene}_seeds_aligned.stk

${hmmer_xanderpatch}/src/hmmbuild --enone ../rev_enone.hmm rev_${gene}_seeds_aligned.stk

${hmmer_xanderpatch}/src/hmmalign --allcol -o ref_aligned.stk ../for_enone.hmm framebot.fa
java -jar ${JAR_DIR}/ReadSeq.jar to-fasta ref_aligned.stk > ../ref_aligned.faa

rm *stk ${gene}_seeds_aligned.fasta rev_${gene}_seeds_aligned.fasta
