#!/usr/bin/python

import urllib2
import os
import sys
import time

if len(sys.argv) != 4 and len(sys.argv) != 5:
	print "USAGE: fetch_genome_xml.py <db> <genome_id_list> <out_dir> [ret_mode]"
	print "\nuse protein for db and xml for ret_mod"
	sys.exit(1)

db = sys.argv[1]
id_file = sys.argv[2]
out_dir = sys.argv[3]
url_template = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=%s&id=%s&rettype=gp&retmode=%s"

if len(sys.argv) == 5:
	ret_mode = sys.argv[4]
else:
	ret_mode = "xml"

print ret_mode
if not os.path.exists(out_dir):
	os.makedirs(out_dir)

for id in open(id_file):
	id = id.strip()
	if id == "":
		continue

	sys.stdout.write("Fetching %s..." % id)
	sys.stdout.flush()
	out_file = os.path.join(out_dir, "%s.%s" % (id, ret_mode))
	print "out_file %s" %(out_file)
	if os.path.exists(out_file):
		print "already fetched"
		continue

	try:
		response = urllib2.urlopen(url_template % (db, id, ret_mode))
		response.getcode()
		if response.getcode() != 200:
			print "Failed"
			continue
		open(out_file, "w").write(response.read())	
	except:
		print "Error:" , sys.exc_info()[1]
			
	time.sleep(1.0/3)
