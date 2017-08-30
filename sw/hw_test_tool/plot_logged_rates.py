#!/usr/bin/env python

import numpy as np
import matplotlib.pyplot as plt
import sys, os, re, argparse
from collections import OrderedDict
import pandas, re

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/testdata/'))
from perc_headers import *

flowRates = OrderedDict()
flowTimes = OrderedDict()

def get_rates(log_file):
    logged_pkts = rdpcap(log_file)
    for pkt in logged_pkts:
        if Perc_control in pkt:
            flowID = pkt.flowID
            if flowID not in flowRates.keys():
                flowRates[flowID] = [pkt.demand]
                flowTimes[flowID] = [pkt.timestamp]
            else:
                flowRates[flowID].append(pkt.demand)
                flowTimes[flowID].append(pkt.timestamp)

def plot_rates(outDir):
    fig_handle =  plt.figure()
    
    # plot the results
    for flowID in flowRates.keys():
        times = flowTimes[flowID]
        rates = flowRates[flowID]
        plt.plot(times, rates, label='flow {0}'.format(flowID), marker='o')
    
    plt.legend()
    plt.title('Flow Rates over time')
    plt.xlabel('time (sec)')
    plt.ylabel('rate (Gbps)')
    plt.show()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('logged_pkts', type=str, help="the pcap file that contains all of the logged control packets from the switch")
    args = parser.parse_args()

    get_rates(args.logged_pkts)
    plot_rates(args.statsDir)

if __name__ == "__main__":
    main()
