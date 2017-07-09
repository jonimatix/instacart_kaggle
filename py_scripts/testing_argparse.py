#!/usr/bin/python3

import argparse

parser = argparse.ArgumentParser()

parser.add_argument('datapath', type=str, action='store')
parser.add_argument('scoretype', type=str, action='store')

args = parser.parse_args()

#print("datapath = ", action='store')
#print("score_type = ", scoretype)

print(args)
print("done")
print("args.datapath = ", args.datapath)

