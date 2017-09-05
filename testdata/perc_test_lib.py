
from nf_sim_tools import *
from perc_headers import *

nf_mac_map = {"nf0":"08:11:11:11:11:08", "nf1":"08:22:22:22:22:08", "nf2":"08:33:33:33:33:08", "nf3":"08:44:44:44:44:08"}

def start_flow_pkt(ingress, egress, flowID, 
                   hopCnt=0, bottleneck_id=(2**8)-1, demand=(2**N)-1,
                   insert_debug=0, timestamp=0,
                   label_0=NEW_FLOW, label_1=NEW_FLOW, label_2=NEW_FLOW,
                   alloc_0=(2**N)-1, alloc_1=(2**N)-1, alloc_2=(2**N)-1):
    assert(hopCnt < 3)
    leave = 0
    isForward = 1
    pkt = Ether(dst=nf_mac_map[egress], src=nf_mac_map[ingress]) / \
          Perc_control(flowID=flowID, leave=leave, isForward=isForward, hopCnt=hopCnt, bottleneck_id=bottleneck_id, demand=demand, insert_debug=insert_debug, timestamp=timestamp, label_0=label_0, label_1=label_1, label_2=label_2, alloc_0=alloc_0, alloc_1=alloc_1, alloc_2=alloc_2)
    pkt = pad_pkt(pkt, 64)
    return pkt

def end_host_response(pkt_in, leave=0):
    pkt = pkt_in.copy()
    tmp_mac = pkt[Ether].dst
    pkt[Ether].dst = pkt[Ether].src
    pkt[Ether].src = tmp_mac
    pkt[Perc_control].leave = leave
    pkt[Perc_control].isForward = pkt[Perc_control].isForward ^ 1 # switch direction
    return pkt

def make_data_pkt(ingress, egress, flowID, size):
    pkt = Ether(dst=nf_mac_map[egress], src=nf_mac_map[ingress]) / \
          Perc_data(flowID=flowID)
    pkt = pad_pkt(pkt, size)
    return pkt

