
import sys, os

sys.path.append(os.path.expandvars('$P4_PROJECT_DIR/sw/division'))
from div_impl import make_tables, divide

from perc_headers import *

CTRL_PORT = 0b01000000

labelMap = {INACTIVE:"INACTIVE", SAT:"SAT", UNSAT:"UNSAT", NEW_FLOW:"NEW_FLOW"}

REG_DEPTH = 4

linkCap_r = 2**31 
sumSat_r = [0,0,0,0]
numSat_r = [0,0,0,0]
numFlows_r = [0,0,0,0]

maxSat_r = 0
nextMaxSat_r = 0

forward = {"08:11:11:11:11:08":0b00000001, "08:22:22:22:22:08":0b00000100, "08:33:33:33:33:08":0b00010000, "08:44:44:44:44:08":0b01000000}

port_index_map = {0b00000001:0, 0b00000100:1, 0b00010000:2, 0b01000000:3}

def process_pkt(pkt_in, src_port, resetMaxSat):
    pkt = pkt_in.copy()
    hp_dst_port = 0
    lp_dst_port = 0
    dst_port = forward_apply(pkt) 

    if Perc_control in pkt:
        hp_dst_port = dst_port | CTRL_PORT
        if (pkt[Perc_control].isForward != 1):
            pkt[Perc_control].hopCnt -= 1
            port = src_port
        else:
            port = dst_port
        index = port_index_map_apply(port) # compute index

        # choose the correct label and alloc based on hopCnt
        if (pkt[Perc_control].hopCnt == 0):
            label = pkt[Perc_control].label_0
            alloc = pkt[Perc_control].alloc_0
        elif (pkt[Perc_control].hopCnt == 1):
            label = pkt[Perc_control].label_1
            alloc = pkt[Perc_control].alloc_1
        else:
            label = pkt[Perc_control].label_2
            alloc = pkt[Perc_control].alloc_2

        (newLabel, newAlloc, sumSatAdj, numSatAdj, numFlowsAdj) = update_agg_state(linkCap_r, pkt[Perc_control].leave, index, label, alloc, pkt[Perc_control].demand)

        # update label and alloc with new values
        if (pkt[Perc_control].hopCnt == 0):
            pkt[Perc_control].label_0 = newLabel
            pkt[Perc_control].alloc_0 = newAlloc
        elif (pkt[Perc_control].hopCnt == 1):
            pkt[Perc_control].label_1 = newLabel
            pkt[Perc_control].alloc_1 = newAlloc
        else:
            pkt[Perc_control].label_2 = newLabel
            pkt[Perc_control].alloc_2 = newAlloc

        R = divide(linkCap_r - sumSatAdj, numFlowsAdj - numSatAdj)

        # fill in new allocation if flow is UNSAT now
        if (newLabel == UNSAT and pkt[Perc_control].hopCnt == 0):
            pkt[Perc_control].alloc_0 = R
        elif (newLabel == UNSAT and pkt[Perc_control].hopCnt == 1):
            pkt[Perc_control].alloc_1 = R
        elif (newLabel == UNSAT and pkt[Perc_control].hopCnt == 2):
            pkt[Perc_control].alloc_2 = R
       
        # update maxSat and nextMaxSat state 
        newMaxSat = update_max_sat(resetMaxSat, index, newLabel, newAlloc)

        if (pkt[Perc_control].insert_debug == 1):
            pkt[Perc_control].timestamp = 0  # cannot know HW timestamp
            pkt[Perc_control].linkCap = linkCap_r
            pkt[Perc_control].sumSatAdj = sumSatAdj
            pkt[Perc_control].numFlowsAdj = numFlowsAdj
            pkt[Perc_control].numSatAdj = numSatAdj
            pkt[Perc_control].newMaxSat = newMaxSat
            pkt[Perc_control].R = R

        # updated requested bandwidth if flow is active
        if (pkt[Perc_control].leave != 1):
            B = max(newMaxSat, R)

            if (pkt[Perc_control].bottleneck_id == pkt[Perc_control].hopCnt):
                # update demand if this is the bottleneck link
                pkt[Perc_control].demand = B
            elif (pkt[Perc_control].demand > B):
                pkt[Perc_control].demand = B
                pkt[Perc_control].bottleneck_id = pkt[Perc_control].hopCnt

        if (pkt[Perc_control].isForward == 1):
            pkt[Perc_control].hopCnt += 1
        
    else:
        # is a data packet
        lp_dst_port = dst_port # send to low priority queue

    if (pkt[Ether].src == pkt[Ether].dst):
        lp_dst_port = 0
        hp_dst_port = 0

    return (pkt, hp_dst_port, lp_dst_port)


def forward_apply(pkt):
    mac = pkt[Ether].dst 
    if mac in forward.keys():
        return forward[mac]
    return 0

def port_index_map_apply(port):
    if port in port_index_map.keys():
        return port_index_map[port]
    print >> sys.stderr, "ERROR: port {} not in port_index_map".format(port)
    sys.exit(1)

def update_agg_state(linkCap_in, leave_in, index_in, label_in, alloc_in, demand_in):
    assert(index_in < REG_DEPTH)

    old_label = label_in
    old_alloc = alloc_in

    C = linkCap_in
    if (label_in == SAT):
        sumSatAdj = sumSat_r[index_in] - alloc_in
        numSatAdj = numSat_r[index_in] - 1
    else:
        sumSatAdj = sumSat_r[index_in]
        numSatAdj = numSat_r[index_in]

    if (label_in == NEW_FLOW):
        numFlowsAdj = numFlows_r[index_in] + 1
    else:
        numFlowsAdj = numFlows_r[index_in]

    if leave_in == 1:
        new_label = INACTIVE
        new_alloc = -1
    else:
        if ((C - sumSatAdj) <= (numFlowsAdj - numSatAdj) * demand_in):
            # flow is UNSAT
            new_label = UNSAT
            new_alloc = -1 # unused 
        else:
            # flow is SAT
            new_label = SAT
            new_alloc = demand_in

    if (old_label == NEW_FLOW and (new_label == SAT or new_label == UNSAT)):
        numFlows_r[index_in] += 1
    elif ((old_label == SAT or old_label == UNSAT) and new_label == INACTIVE):
        numFlows_r[index_in] -= 1

    # Update switch state based on (old_label, new_label, old_alloc, new_alloc)
    if ((old_label == NEW_FLOW or old_label == UNSAT) and new_label == SAT):
        sumSat_r[index_in] += new_alloc
        numSat_r[index_in] += 1
    elif (old_label == SAT and new_label == SAT):
        sumSat_r[index_in] = sumSat_r[index_in] - old_alloc + new_alloc
    elif (old_label == SAT and (new_label == UNSAT or new_label == INACTIVE)):
        sumSat_r[index_in] -= old_alloc
        numSat_r[index_in] -= 1

    return (new_label, new_alloc, sumSatAdj, numSatAdj, numFlowsAdj)


def update_max_sat(resetMaxSat_in, index_in, newLabel_in, newAlloc_in):
    global maxSat_r, nextMaxSat_r
    if (resetMaxSat_in):
        if (newLabel_in == SAT):
            newMaxSat = max(newAlloc_in, nextMaxSat_r)
        else:
            newMaxSat = nextMaxSat_r
        newNextMaxSat = 0
    elif (newLabel_in == SAT):
        newMaxSat = max(newAlloc_in, maxSat_r)
        newNextMaxSat = max(newAlloc_in, nextMaxSat_r)
    else:
        newMaxSat = maxSat_r
        newNextMaxSat = nextMaxSat_r

    maxSat_r = newMaxSat
    nextMaxSat_r = newNextMaxSat

    return newMaxSat







