import sys
import os
import glob

## all the matches 
matchSet = set()
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
	lineageStarted = False
	for l in lines:
	##Lineage MatchName       Abundance       Fraction Abundance
		l = l.strip()
		if l.startswith("Lineage"):
			lineageStarted = True
			continue;
		if not lineageStarted:
			continue	
		lexems = l.split();
		matchSet.add(lexems[1])
		sampleTaxaSet[lexems[1]] = lexems[2]
		sum += float ( lexems[2])
	sampleTaxaSet["SUM"] = sum	


if __name__ == "__main__":
## this program takes one or more taxonabund.txt files form Xander output, 
## merge the nearest match results from these files into one file to make easy to load to excel or other program
	usage = "Usage: taxonabund.txt taxonabund.txt ... > merged_Nearestmatch.txt"
	if len(sys.argv) < 2:
		sys.exit("need at least one input file. " + usage);
	for arg in sys.argv[1:]:
		infiles = glob.glob(arg)
		for infile in infiles:
			parse(infile)
			
	
	## print the match abundance
	sys.stdout.write( "\nMatchName")
	for name in matchSet:
		sys.stdout.write( "\t%s" %(name))
	sys.stdout.write( "\n")
	for file in sampleSet:
		sys.stdout.write( file)
		for match in matchSet:
			if match in sampleSet[file].keys():
				sys.stdout.write( "\t%s" %(sampleSet[file][match]))
			else:
				sys.stdout.write( "\t0")	
		sys.stdout.write( "\n")
	sys.stdout.write( "\n")
