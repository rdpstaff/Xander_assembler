import sys
import os

args = sys.argv[1:]

for fname in args:
	if not os.path.exists(fname):
		print "Error: " + fname + " does not exist"
		continue

	fin = open(fname)
	fout = open("rev_" + fname, 'w')

	for line in fin:
		if line[0] == '>':
			fout.write(line)
		else:
			old_seq = line[:-1]
			seq = ""
			for i in range(len(old_seq)):
				x = -(i+1)
				seq += old_seq[x]
			fout.write(seq + '\n')
	fin.close()
	fout.close()
