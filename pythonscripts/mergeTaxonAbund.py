import sys
import os
import glob

## all the taxa
taxaSet = set()
## all the samples
sampleSet = dict()

def parse(infile):
	#the taxa for this sample
	filename = os.path.basename(infile.replace("_taxonabund.txt", ""))
	sampleTaxaSet = dict()
	sampleSet[filename] = sampleTaxaSet
	infile = open(infile, "r")
	lines = infile.readlines()
	infile.close()
	sum = 0
	for l in lines:
		l = l.strip()
		if l.startswith("Taxon"):
			continue;
		if l == ""	:
			break
		lexems = l.split();
		taxaSet.add(lexems[0])
		sampleTaxaSet[lexems[0]] = lexems[2]
		sum += float ( lexems[1])
	sampleTaxaSet["SUM"] = sum	


if __name__ == "__main__":
## this program takes one or more taxonabund.txt files form Xander output, 
## merge the taxon abundance results from these files into one file to make easy to load to excel or other program
	usage = "Usage: taxonabund.txt taxonabund.txt ... > merged_taxonabund.txt"
	if len(sys.argv) < 2:
		sys.exit("need at least one input file. " + usage);

	for arg in sys.argv[1:]:
		infiles = glob.glob(arg)
		for infile in infiles:
			parse(infile)
			
	
	## print the total number of seqs
	sys.stdout.write( "Sample")
	for file in sampleSet:
		sys.stdout.write( "\t%s" %(file) )
	sys.stdout.write( "\n")
	sys.stdout.write( "Count")
	for file in sampleSet:
		sys.stdout.write( "\t%s" %(sampleSet[file]["SUM"]) )
	sys.stdout.write( "\n")
	
	
	## print the taxa abundance
	sys.stdout.write( "\nTaxonAbund")
	for file in sampleSet:
		sys.stdout.write( "\t%s" %(file))
	sys.stdout.write( "\n")
	for taxon in taxaSet:
		sys.stdout.write( taxon )
		for file in sampleSet:
			if taxon in sampleSet[file].keys():
				sys.stdout.write( "\t%s" %(sampleSet[file][taxon]))
			else:
				sys.stdout.write( "\t0")	
		sys.stdout.write( "\n")
	sys.stdout.write( "\n")
