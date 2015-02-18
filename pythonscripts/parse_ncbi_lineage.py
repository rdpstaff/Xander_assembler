#!/usr/bin/python

import sys
import re
import os
from Bio import SeqIO
from xml.dom import minidom

## to extract from xml format
## this is not used because it's slow to parse xml file
def extractXml(origseq, input_xml, out_file):
	accno = origseq.id.split("_")[0]
	xmldoc = minidom.parse(input_xml)
    
	GBSeq = xmldoc.getElementsByTagName("GBSet")[0]
	out_file.write(">" + origseq.id)
	#seq = GBSeq.getElementsByTagName("GBSeq_organism")[0]
	#output_file.write("_" + re.sub(" ", "_", seq.firstChild.data))
	out_file.write('\t')
	seq = GBSeq.getElementsByTagName("GBSeq_taxonomy")[0]
	out_file.write(re.sub(" ", "", seq.firstChild.data))    
	out_file.write("\n%s\n" %(origseq.seq) )
  
def extractXmlLineage(origseq, input_xml, out_file):
	accno = origseq.id.split("_")[0]
	f = open (input_xml)
	for line in f:
		line = line.strip()
		if line.startswith("<GBSeq_taxonomy>"):
			taxonomy = line.split("<")[1].replace("GBSeq_taxonomy>", "").replace(" ", "")
			break;
	out_file.write(">%s\t%s\n%s\n" %( origseq.id, taxonomy, origseq.seq ))	

	

def main(args):
	input_fasta = args[0]
	input_xml_dir = args[1]
	output_file_name = args[2]
	out_file = open(output_file_name, 'w')

	for seq in SeqIO.parse(open(input_fasta), "fasta"):		
		accno = seq.id.split("_")[0]
		xmlfile = os.path.join(os.path.abspath(input_xml_dir), accno + ".xml")
		if os.path.exists(xmlfile):
			extractXmlLineage(seq, xmlfile, out_file)
		else: 
			out_file.write(">%s\n%s\n" %( seq.id,seq.seq ))
				
	out_file.close()	

if __name__ == "__main__":
	usage = "origseq.fasta xml_dir outfile\nxml_dir contained the xml files fected from NCBI, using fecth_ncbi_xml.py"
	if len(sys.argv) != 4 :
		print "Incorrect number of arguments %s" %(usage)
		sys.exit()
	main(sys.argv[1:])
                        