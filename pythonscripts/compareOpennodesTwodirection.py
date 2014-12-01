import sys
import io
import numpy as np

class Stat:
	def __init__(self, Lcount, LopenC, LcloseC, Rcount, RopenC, RcloseC):
		self.Lcount = Lcount
		self.Lopenlist = LopenC
		self.Lcloselist = LcloseC
		self.Rcount = Rcount
		self.Ropenlist = RopenC
		self.Rcloselist = RcloseC

#read file 
def parse(infile):
	Lopenlist = []
	Lcloselist = []
	Ropenlist = []
	Rcloselist = []
	Rcount = 0	
	Lcount = 0
	## left direction occurred first
	## right direction occurred later
	## this only works for single path
	prevLOpen = 0
	prevLClose = 0
	prevROpen = 0
	prevRClose = 0
	current = "left"
	
	for line in open(infile, "r"):
		line = line.strip();
		lexems = line.split()
		## add the number before the left direction		
		if lexems[0] == "left":
			current = lexems[0]
			if ( prevROpen + prevRClose ) >= 1:
				Rcount+=1
				Ropenlist.append( prevROpen )
				Rcloselist.append( prevRClose )
			
			prevROpen = 0
			prevRClose = 0
			
			
		if lexems[0] == "right":
			current = lexems[0]
			if ( prevLOpen + prevLClose ) >= 1:
				Lcount+=1
				Lopenlist.append( prevLOpen )
				Lcloselist.append( prevLClose )
			
			prevLOpen = 0
			prevLClose = 0	
		
		if (len(lexems)== 8 and lexems[7] in ["true", "false"] and lexems[3] != "-" ) or len(lexems)== 7 and lexems[6] in ["true", "false"] and lexems[3] != "-":
			if current == "left":
				prevLOpen +=int(lexems[1])
				prevLClose += int(lexems[3])	
			else:
				prevROpen +=int(lexems[1])
				prevRClose += int(lexems[3])	
	
	#last number
	if ( prevROpen + prevRClose ) >= 1:
		Rcount+=1
		Ropenlist.append( prevROpen )
		Rcloselist.append( prevRClose )
	if ( prevLOpen + prevLClose ) >= 1:
		Lcount+=1
		Lopenlist.append( prevLOpen )
		Lcloselist.append( prevLClose )
				
	stat = Stat(Lcount, np.array(Lopenlist), np.array(Lcloselist), Rcount, np.array(Ropenlist), np.array(Rcloselist))			
	return stat
	

if __name__ == "__main__":
	stat1 = parse(sys.argv[1])
	stat2 = parse(sys.argv[2])
	# left direction
	print "%s_Left\tkmerCount\t%s\topenNodes\t%s\tcloseNodes\t%s\tMaxOpen\t%s\tMaxClose\t%s\tMedianOpen\t%s\tMedianClose\t%s" %(sys.argv[1], stat1.Lcount, np.sum(stat1.Lopenlist), np.sum(stat1.Lcloselist), np.max(stat1.Lopenlist), np.max(stat1.Lcloselist), np.median(stat1.Lopenlist), np.median(stat1.Lcloselist) )
	print "%s_Left\tkmerCount\t%s\topenNodes\t%s\tcloseNodes\t%s\tMaxOpen\t%s\tMaxClose\t%s\tMedianOpen\t%s\tMedianClose\t%s" %(sys.argv[2], stat2.Lcount, np.sum(stat2.Lopenlist), np.sum(stat2.Lcloselist), np.max(stat2.Lopenlist), np.max(stat2.Lcloselist),np.median(stat2.Lopenlist), np.median(stat2.Lcloselist) )

	print "%s_Left\t%s\tpctOfOpenNodes\t%s\tpctOfCloseNodes\t%s\n" %(sys.argv[1], sys.argv[2], 100*np.sum(stat1.Lopenlist)/np.sum(stat2.Lopenlist), 100*np.sum(stat1.Lcloselist)/np.sum(stat2.Lcloselist) )
	## right direction
	print "%s_right\tkmerCount\t%s\topenNodes\t%s\tcloseNodes\t%s\tMaxOpen\t%s\tMaxClose\t%s\tMedianOpen\t%s\tMedianClose\t%s" %(sys.argv[1], stat1.Rcount, np.sum(stat1.Ropenlist), np.sum(stat1.Rcloselist), np.max(stat1.Ropenlist), np.max(stat1.Rcloselist), np.median(stat1.Ropenlist), np.median(stat1.Rcloselist) )
	print "%s_Right\tkmerCount\t%s\topenNodes\t%s\tcloseNodes\t%s\tMaxOpen\t%s\tMaxClose\t%s\tMedianOpen\t%s\tMedianClose\t%s" %(sys.argv[2], stat2.Rcount, np.sum(stat2.Ropenlist), np.sum(stat2.Rcloselist), np.max(stat2.Ropenlist), np.max(stat2.Rcloselist),np.median(stat2.Ropenlist), np.median(stat2.Rcloselist) )

	print "%s_Right\t%s\tpctOfOpenNodes\t%s\tpctOfCloseNodes\t%s\n" %(sys.argv[1], sys.argv[2], 100*np.sum(stat1.Ropenlist)/np.sum(stat2.Ropenlist), 100*np.sum(stat1.Rcloselist)/np.sum(stat2.Rcloselist) )
