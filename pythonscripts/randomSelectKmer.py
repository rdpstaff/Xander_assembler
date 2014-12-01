import random
import sys
import os
sys.path.append(os.path.abspath("/mnt/research/rdp/private/Qiong_xander_analysis/pythonscripts/"))
import getUniqueStarts

usage = "infile select_num sort(Y|N)"
select_num = int(sys.argv[2])
uniquelines = getUniqueStarts.getUnique(sys.argv[1])
rdm_sample = random.sample(uniquelines, select_num)

needsort = (sys.argv[3] == 'Y')
if needsort:
	sorted_sample = getUniqueStarts.sortStartKmer(rdm_sample)
	for s in sorted_sample :
		print "%s" %(s[0])
else:
	for s in rdm_sample:
		print "%s" %(s)
