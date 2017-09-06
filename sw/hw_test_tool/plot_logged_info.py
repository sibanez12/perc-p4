#!/usr/bin/env python

import numpy as np
import matplotlib
import matplotlib.pyplot as plt
import sys, os, re, argparse
from collections import OrderedDict
import pandas, re, csv
from threading import Thread

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/testdata/'))
from perc_headers import *

flowTimes = OrderedDict()
flowDemands = OrderedDict()
flowAllocs = OrderedDict()
flowLabels = OrderedDict()
flowLinkCaps = OrderedDict()
flowSumSats = OrderedDict()
flowNumFlows = OrderedDict()
flowNumSats = OrderedDict()
flowNewMaxSats = OrderedDict()
flowRs = OrderedDict()

LINK_CAP = 2**31

def get_flow_info(log_file):
    logged_pkts = rdpcap(log_file)
    for pkt in logged_pkts:
        if Perc_control in pkt:
            flowID = pkt.flowID
            if flowID not in flowTimes.keys():
                flowTimes[flowID] = [pkt.timestamp*5.0]
                flowDemands[flowID] = [(float(pkt.demand)/LINK_CAP)*10] 
                flowAllocs[flowID] = [(float(pkt.alloc_0)/LINK_CAP)*10]
                flowLabels[flowID] = [pkt.label_0] 
                flowLinkCaps[flowID] = [(float(pkt.linkCap)/LINK_CAP)*10] 
                flowSumSats[flowID] = [(float(pkt.sumSatAdj)/LINK_CAP)*10] 
                flowNumFlows[flowID] = [pkt.numFlowsAdj] 
                flowNumSats[flowID] = [pkt.numSatAdj]
                flowNewMaxSats[flowID] = [(float(pkt.newMaxSat)/LINK_CAP)*10]
                flowRs[flowID] = [(float(pkt.R)/LINK_CAP)*10]
            else:
                flowTimes[flowID].append(pkt.timestamp*5.0)
                flowDemands[flowID].append((float(pkt.demand)/LINK_CAP)*10)
                flowAllocs[flowID].append((float(pkt.alloc_0)/LINK_CAP)*10)
                flowLabels[flowID].append(pkt.label_0)
                flowLinkCaps[flowID].append((float(pkt.linkCap)/LINK_CAP)*10)
                flowSumSats[flowID].append((float(pkt.sumSatAdj)/LINK_CAP)*10)
                flowNumFlows[flowID].append(pkt.numFlowsAdj)
                flowNumSats[flowID].append(pkt.numSatAdj)
                flowNewMaxSats[flowID].append((float(pkt.newMaxSat)/LINK_CAP)*10)
                flowRs[flowID].append((float(pkt.R)/LINK_CAP)*10)

def report_rtt():
    for flowID, times in flowTimes.items():
        diff = [j-i for i, j in zip(times[:-1], times[1:])]
        avg_rtt = 2.0*np.mean(diff)
        max_diff = max(diff)
        print "flow {}:".format(flowID)
        print "\tavg_rtt = ", avg_rtt , " (ns)"
        print "\tmax_diff = ", max_diff, " (ns)"

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

def plot_flow_data(flow_data, title, y_label, y_lim=None):
    fig_handle =  plt.figure()
    
    # plot the results
    for flowID in flow_data.keys():
        times = flowTimes[flowID]
        y_vals = flow_data[flowID]
        plt.plot(times, y_vals, label='flow {0}'.format(flowID), marker='o')
    
    plt.legend()
    plt.title(title)
    plt.xlabel('time (ns)')
    plt.ylabel(y_label)
    if y_lim is not None:
        axes = plt.gca()
        axes.set_ylim(y_lim)
#    plt.show()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--all', action='store_true', default=False, help='plot all the info about the flows')
    parser.add_argument('--demand', action='store_true', default=False, help='plot the demands of each flow')
    parser.add_argument('--alloc', action='store_true', default=False, help='plot the allocation of each flow')
    parser.add_argument('--label', action='store_true', default=False, help='plot the label of each flow')
    parser.add_argument('--linkCap', action='store_true', default=False, help='plot the linkCap in each pkt')
    parser.add_argument('--sumSat', action='store_true', default=False, help='plot the sumSat of each flow')
    parser.add_argument('--numFlows', action='store_true', default=False, help='plot the numFlows of each flow')
    parser.add_argument('--numSat', action='store_true', default=False, help='plot the numSat of each flow')
    parser.add_argument('--maxSat', action='store_true', default=False, help='plot the newMaxSat of each flow')
    parser.add_argument('--R', action='store_true', default=False, help='plot the R of each flow')
    parser.add_argument('--rtt', action='store_true', default=False, help='report the average rtt')
    parser.add_argument('logged_pkts', type=str, help="the pcap file that contains all of the logged control packets from the switch")
    args = parser.parse_args()

    get_flow_info(args.logged_pkts)
    if (args.rtt or args.all):
        report_rtt()

    if (args.demand or args.all):
        plot_flow_data(flowDemands, 'Flow demands over time', 'rate (Gbps)', y_lim=[0,11])
    if (args.alloc or args.all):
        plot_flow_data(flowAllocs, 'Flow allocations over time', 'rate (Gbps)')
    if (args.label or args.all):
        plot_flow_data(flowLabels, 'Flow labels over time', 'label', y_lim=[0,3])
    if (args.linkCap or args.all):
        plot_flow_data(flowLinkCaps, 'Flow linkCap measurements over time', 'rate (Gbps)', y_lim=[0,11])
    if (args.sumSat or args.all):
        plot_flow_data(flowSumSats, 'Flow sumSat state over time', 'rate (Gbps)', y_lim=[0,11])
    if (args.numFlows or args.all):
        plot_flow_data(flowNumFlows, 'Flow numFlows state over time', 'numFlows')
    if (args.numSat or args.all):
        plot_flow_data(flowNumSats, 'Flow numSat state over time', 'numSat')
    if (args.maxSat or args.all):
        plot_flow_data(flowNewMaxSats, 'Flow maxSat state over time', 'rate (Gbps)', y_lim=[0,11])
    if (args.R or args.all):
        plot_flow_data(flowRs, 'Flow R measurements over time', 'rate (Gbps)', y_lim=[0,11])

    font = {'family' : 'normal',
            'weight' : 'bold',
            'size'   : 22}
    
    matplotlib.rc('font', **font)

    plt.show()


if __name__ == "__main__":
    main()
