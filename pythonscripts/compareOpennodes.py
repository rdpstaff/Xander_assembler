import sys
import io
import numpy as np

class Stat:
	def __init__(self, count, openC, closeC):
		self.count = count
		self.openlist = openC
		self.closelist = closeC

#read file 
def parse(infile):
	openlist = []
	closelist = []
	count = 0	
	## left direction occurred first
	## right direction occurred later
	## this only works for single path
	prevOpen = 0
	prevClose = 0
	
	for line in open(infile, "r"):
		line = line.strip();
		lexems = line.split()
		## add the number before the left direction
		if lexems[0] == "left":
			if ( prevOpen + prevClose ) >= 1:
				count+=1
				openlist.append( prevOpen )
				closelist.append( prevClose )
			
			prevOpen = 0
			prevClose = 0
			
		
		if len(lexems)== 8 and lexems[7] in ["true", "false"] and lexems[3] != "-" :					
			prevOpen +=int(lexems[1])
			prevClose += int(lexems[3])
		elif len(lexems)== 7 and lexems[6] in ["true", "false"] and lexems[3] != "-":
			prevOpen +=int(lexems[1])
			prevClose += int(lexems[3])	
	#last number
	if ( prevOpen + prevClose ) >= 1:
		count+=1
		openlist.append( prevOpen )
		closelist.append( prevClose )
					
	stat = Stat(count, np.array(openlist), np.array(closelist))			
	return stat
	

if __name__ == "__main__":
	stat1 = parse(sys.argv[1])
	stat2 = parse(sys.argv[2])
	print "%s\tkmerCount\t%s\topenNodes\t%s\tcloseNodes\t%s\tMaxOpen\t%s\tMaxClose\t%s\tMedianOpen\t%s\tMedianClost\t%s" %(sys.argv[1], stat1.count, np.sum(stat1.openlist), np.sum(stat1.closelist), np.max(stat1.openlist), np.max(stat1.closelist), np.median(stat1.openlist), np.median(stat1.closelist) )
	print "%s\tkmerCount\t%s\topenNodes\t%s\tcloseNodes\t%s\tMaxOpen\t%s\tMaxClose\t%s\tMedianOpen\t%s\tMedianClost\t%s" %(sys.argv[2], stat2.count, np.sum(stat2.openlist), np.sum(stat2.closelist), np.max(stat2.openlist), np.max(stat2.closelist),np.median(stat2.openlist), np.median(stat2.closelist) )

	print "%s\t%s\tpctOfOpenNodes\t%s\tpctOfCloseNodes\t%s\n" %(sys.argv[1], sys.argv[2], 100*np.sum(stat1.openlist)/np.sum(stat2.openlist), 100*np.sum(stat1.closelist)/np.sum(stat2.closelist) )
