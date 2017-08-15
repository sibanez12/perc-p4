#!/usr/bin/env python

"""
This script is meant to test the accuracy and precision of the division
implementation using log_table abd exp_table
"""

import sys, os, argparse, random
from collections import OrderedDict
import numpy as np

from div_impl import *

"""
N=16, m=6, l=9 gives these results:
len(log_table) =  383
total_mem = 1885.75 bytes

if error = abs(exact - approx)/exact * 100
    avg error = 11.3274599513 %
    std dev error = 9.37065574409 %

if error = abs(exact - approx)/(2^N-1) * 100
    avg error = 0.000499021043359 %
    std dev error = 0.00643801159808 %
"""
 
def run_test():
    error = []
    for i in range(10000):
        a = random.randint(0, 2**N-1)
        b = random.randint(1, a)
        approx = divide(a, b)
        exact = int(round(float(a)/float(b)))
        e = abs(approx - exact)/(exact) * 100.0
        error.append(e)

    avg_error = np.average(error)
    std_dev = np.std(error)
    print "avg error = {} %".format(avg_error)
    print "std dev error = {} %".format(std_dev)


def main():
#    parser = argparse.ArgumentParser()
#    parser.add_argument('a', type=int, help="numerator")
#    parser.add_argument('b', type=int, help="denominator")
#    args = parser.parse_args()

    make_tables()
    print "len(log_table) = ", len(log_table)
    total_mem = (len(log_table)*l*2 + len(exp_table)*N)/8.0
    print "total_mem = {} bytes".format(total_mem) 

#    print_log_table()
#    print ""
#    print_exp_table()

    run_test()

#    approx = divide(args.a, args.b)
#    actual = float(args.a)/float(args.b)
#    print "Computing: {}/{}".format(args.a, args.b)
#    print "\tapproximate = ", approx
#    print "\tactual = ", actual
#    print "\t% error = ", abs(approx - actual)/actual * 100.0

if __name__ == "__main__":
    main()


