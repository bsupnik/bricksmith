#!/usr/bin/python

import os,sys

def fail(x):
	print x
	exit(1)

def line_match(line,want):
	if len(line) < len(want): 
		return False
	n=0
	for w in want:
		if line[n] != w:
			return False
		n = n + 1
	return True
	
def check_same_matrix(part_a,part_b):
	mat_a = part_a[2:14]
	mat_b = part_b[2:14]
	return mat_a == mat_b

def output_pairs(parents,children,relation):
	if len(parents) < 1:
		fail('Relation %s has 0 parents.' % relation)
	if len(children) < 1:
		return
	
	for p in parents:
		if not check_same_matrix(parents[0],p):
			fail('Relation %s: matrices do not match.' % relation)

	offset = [ int(x) for x in parents[0][2:5] ]
	
	for p in parents:
		for c in children:
			child_xform = [ float(x) for x in c[2:14]]
			#parent child trans rotate relation name
			#122c01.dat	3641.dat	-31 6 0 0 0 1 0 1 0 -1 0 0	Left Tire
			print ('%s\t%s\t%d %d %d\t%d %d %d  %d %d %d  %d %d %d  %s' %
				(p[14],c[14],
					child_xform[0]-offset[0],					child_xform[1]-offset[1],					child_xform[2]-offset[2],
					child_xform[3],child_xform[4],child_xform[5],
					child_xform[6],child_xform[7],child_xform[6],
					child_xform[9],child_xform[10],child_xform[11],
					relation))

for fname in sys.argv[1:]:
	fi = open(fname)

	relation=None
	step = 0
	got_mpd = 0
	parents=None
	children=None
	
	for raw_line in fi:
		line = raw_line.strip('\r\n \t').split()
		#print line

		if line_match(line,('0')) and got_mpd:
			relation = ' '.join(line[1:])
			parents=[]
			children=[]

		if line_match(line,('0','FILE')):
			got_mpd = 1
			step = 1
		else:
			got_mpd = 0

		if line_match(line,('0','STEP')):
			step = step + 1
			if step == 3:
				output_pairs(parents,children,relation)
				parents=[]
				children=[]
				step = 1
		
		if line_match(line,('0','NOFILE')):
			parents=None
			children=None

		if line_match(line,('1')):
			if step == 1:
				parents.append(line)
			elif step == 2:
				children.append(line)
			else:
				fail('ERROR: 1 line not in step %d' % step)
