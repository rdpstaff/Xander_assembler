import random
import sys
import os
from operator import itemgetter, attrgetter

kmerset = dict()

def sortStartKmer(data):
	starts = []
	for line in data:
		lexems = line.split()
		tuple = (line, int(lexems[7]))
		starts.append(tuple)
		
	starts.sort(key=lambda tup: tup[1], reverse=True)  	
	return starts
	
def getUnique(startsfile):

	infile = open(startsfile, "r")
	lines = infile.readlines()
	infile.close()
	for l in lines:
		if l.startswith("#"):
			continue;
		lexems = l.split();
		kmer_pos = lexems[3] + "_" + lexems[7]
		if kmer_pos not in kmerset:
			kmerset[kmer_pos] = l.strip();	
	return kmerset.values()

if __name__ == "__main__":
	usage = "Usage: starts.txt starts.txt ... > uniq_starts.txt"
	if len(sys.argv) < 2:
		sys.exit("need at least one input file. " + usage);
	for infile in sys.argv[1:]:
		getUnique(infile)
	ret = kmerset.values()
	sort_data = sortStartKmer(ret)
	for s in sort_data:
		print "%s" %(s[0])

