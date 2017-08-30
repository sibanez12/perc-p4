#!/usr/bin/env python

import numpy as np
import matplotlib.pyplot as plt
import sys, os, re, argparse
from collections import OrderedDict
import pandas, re, csv

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/testdata/'))
from perc_headers import *

flowRates = OrderedDict()
flowTimes = OrderedDict()
flowAllocs = OrderedDict()
flowLabels = OrderedDict()
flowDemands = OrderedDict()

LINK_CAP = 2**31

def get_rates(log_file):
    logged_pkts = rdpcap(log_file)
    for pkt in logged_pkts:
        if Perc_control in pkt:
            flowID = pkt.flowID
            if flowID not in flowRates.keys():
                flowRates[flowID] = [(float(pkt.demand)/LINK_CAP)*10] # convert to Gbps
                flowTimes[flowID] = [pkt.timestamp*5.0]               # convert to ns
                flowAllocs[flowID] = [pkt.alloc_0]
                flowLabels[flowID] = [pkt.label_0]
                flowDemands[flowID] = [pkt.demand]
            else:
                flowRates[flowID].append((float(pkt.demand)/LINK_CAP)*10) # convert to Gbps
                flowTimes[flowID].append(pkt.timestamp*5.0)               # convert to ns
                flowAllocs[flowID].append(pkt.alloc_0)
                flowLabels[flowID].append(pkt.label_0)
                flowDemands[flowID].append(pkt.demand)

def dump_flow_info():
     # plot the results
    for flowID in flowRates.keys():
        times = flowTimes[flowID]
        demands = flowDemands[flowID]
        allocs = flowAllocs[flowID]
        labels = flowLabels[flowID]
        with open('flow_{}_rate.csv'.format(flowID), 'wb') as csvfile:
            wr = csv.writer(csvfile)
            wr.writerow(times)
            wr.writerow(demands)
            wr.writerow(allocs)
            wr.writerow(labels)

def plot_rates():
    fig_handle =  plt.figure()
    
    # plot the results
    for flowID in flowRates.keys():
        times = flowTimes[flowID]
        rates = flowRates[flowID]
        plt.plot(times, rates, label='flow {0}'.format(flowID), marker='o')
    
    plt.legend()
    plt.title('Flow Rates over time')
    plt.xlabel('time (ns)')
    plt.ylabel('rate (Gbps)')
    axes = plt.gca()
    axes.set_ylim([0,11])
    plt.show()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dump', action='store_true', default=False, help='dump the flow rates to csv files')
    parser.add_argument('logged_pkts', type=str, help="the pcap file that contains all of the logged control packets from the switch")
    args = parser.parse_args()

    get_rates(args.logged_pkts)
    if (args.dump):
        dump_flow_info()
    plot_rates()

if __name__ == "__main__":
    main()
