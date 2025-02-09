"""
Use this file to graph search results from test_outputs/ dir
Example:
    python3 graph.py -i PASSresult_1_192_3383_0.txt
"""
import os
import sys
import argparse
import csv
from mpl_toolkits import mplot3d
import matplotlib.pyplot as plt
import numpy as np

CWD          = os.getcwd()

parser = argparse.ArgumentParser()
parser.add_argument(
   '-s', '--save',
   action      = "store_true",
   help        = 'Save the file into an image (TODO)'
)
parser.add_argument(
   '-i', '--input',
   metavar     = '',
   default     = '',
   help        = 'path to file'
)
args = parser.parse_args()

filename = CWD+f'/{args.input}'
print(filename)
n_results=[]
fd_results=[]
search_results=[]
with open(filename, 'r') as f_in:
    csvFile = csv.reader(f_in)
    for lines in csvFile:
        n_results.append(float(lines[0]))
        fd_results.append(float(lines[1]))
        search_results.append(float(lines[2]))

fig = plt.figure()
ax = plt.axes(projection ='3d')
ax.plot(n_results, fd_results, search_results, 'green')
#ax.scatter(n_results, fd_results, search_results, c=search_results)
ax.set_title('GPS Search results')
plt.show()

#if args.save: TODO
