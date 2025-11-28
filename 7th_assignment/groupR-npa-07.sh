#!/bin/bash
# Solution for Assignment 7

# Group members:
# Lukas Franz 0530099
# Vincent Rinnert 0522118
# Noah Stein 0527436

# Optional script to clear all the namespaces to test properly - use by running ./exercise7.sh clear
if [[ $1 == "clear" ]]; then
    for ns in H1 H2 R1 R2 R3 R4 R5; do
        sudo ip netns delete $ns 2>/dev/null
    done
    echo "All namespaces deleted."
    exit 0
fi

# Question 1 a) creating namespaces
# creating the hosts
ip netns add H1
ip netns add H2
# Creating the switches
ip netns add R1
ip netns add R2
ip netns add R3
ip netns add R4
ip netns add R5
# Listing them
ip netns list

# Question 1 b)
# Function to create a veth link between two namespaces

create_link() {
    ns1=$1
    ns2=$2
    veth1="veth-${ns1}-${ns2}"
    veth2="veth-${ns2}-${ns1}"
    # Create veth pair
    sudo ip link add $veth1 type veth peer name $veth2
    # Move interfaces into namespaces
    sudo ip link set $veth1 netns $ns1
    sudo ip link set $veth2 netns $ns2
    # Set link up immediately
    sudo ip netns exec $ns1 ip link set $veth1 up
    sudo ip netns exec $ns2 ip link set $veth2 up
    echo "Link created: $ns1 <-> $ns2"
}

# Create all links
create_link H1 R1
create_link R1 R2
create_link R1 R4
create_link R2 R3
create_link R3 R5
create_link R5 R4
create_link R5 H2

# Question 1 c)
# Assign IPv6 addresses to all interfaces according to the subnets 

# H1 <-> R1 subnet 2001:DB8:1::/64
sudo ip netns exec H1 ip -6 addr add 2001:DB8:1::1/64 dev veth-H1-R1
sudo ip netns exec R1 ip -6 addr add 2001:DB8:1::2/64 dev veth-R1-H1

# R1 <-> R2 subnet 2001:DB8:2::/64
sudo ip netns exec R1 ip -6 addr add 2001:DB8:2::1/64 dev veth-R1-R2
sudo ip netns exec R2 ip -6 addr add 2001:DB8:2::2/64 dev veth-R2-R1

# R2 <-> R3 subnet 2001:DB8:3::/64
sudo ip netns exec R2 ip -6 addr add 2001:DB8:3::1/64 dev veth-R2-R3
sudo ip netns exec R3 ip -6 addr add 2001:DB8:3::2/64 dev veth-R3-R2

# R3 <-> R5 subnet 2001:DB8:5::/64
sudo ip netns exec R3 ip -6 addr add 2001:DB8:5::1/64 dev veth-R3-R5
sudo ip netns exec R5 ip -6 addr add 2001:DB8:5::2/64 dev veth-R5-R3

# R1 <-> R4 subnet 2001:DB8:4::/64
sudo ip netns exec R1 ip -6 addr add 2001:DB8:4::1/64 dev veth-R1-R4
sudo ip netns exec R4 ip -6 addr add 2001:DB8:4::2/64 dev veth-R4-R1

# R4 <-> R5 subnet 2001:DB8:6::/64
sudo ip netns exec R4 ip -6 addr add 2001:DB8:6::1/64 dev veth-R4-R5
sudo ip netns exec R5 ip -6 addr add 2001:DB8:6::2/64 dev veth-R5-R4

# R5 <-> H2 subnet 2001:DB8:7::/64
sudo ip netns exec R5 ip -6 addr add 2001:DB8:7::1/64 dev veth-R5-H2
sudo ip netns exec H2 ip -6 addr add 2001:DB8:7::2/64 dev veth-H2-R5

# Question 1 d)
# Run route commands in each namespace of H1 and H2

# H1 default route via R1
sudo ip netns exec H1 ip -6 route add default via 2001:DB8:1::2 dev veth-H1-R1

# H2 default route via R5
sudo ip netns exec H2 ip -6 route add default via 2001:DB8:7::1 dev veth-H2-R5


# Question 1 e) 
# Assign loopback interfaces to routers: 

sudo ip netns exec R1 ip -6 addr add fc00:1::1/128 dev lo
sudo ip netns exec R2 ip -6 addr add fc00:2::1/128 dev lo
sudo ip netns exec R3 ip -6 addr add fc00:3::1/128 dev lo
sudo ip netns exec R4 ip -6 addr add fc00:4::1/128 dev lo
sudo ip netns exec R5 ip -6 addr add fc00:5::1/128 dev lo

# Bring up Loopbacks
for ns in H1 H2 R1 R2 R3 R4 R5; do
    sudo ip netns exec $ns ip link set lo up
done

# Question 1 f)
# Define routes for every other router on each router:

# --- On R1 ---
sudo ip netns exec R1 ip -6 route add fc00:2::1/128 via 2001:DB8:2::2 dev veth-R1-R2
sudo ip netns exec R1 ip -6 route add fc00:3::1/128 via 2001:DB8:2::2 dev veth-R1-R2
sudo ip netns exec R1 ip -6 route add fc00:4::1/128 via 2001:DB8:4::2 dev veth-R1-R4
sudo ip netns exec R1 ip -6 route add fc00:5::1/128 via 2001:DB8:4::2 dev veth-R1-R4

# --- On R2 ---
sudo ip netns exec R2 ip -6 route add fc00:1::1/128 via 2001:DB8:2::1 dev veth-R2-R1
sudo ip netns exec R2 ip -6 route add fc00:3::1/128 via 2001:DB8:3::2 dev veth-R2-R3
sudo ip netns exec R2 ip -6 route add fc00:4::1/128 via 2001:DB8:2::1 dev veth-R2-R1
sudo ip netns exec R2 ip -6 route add fc00:5::1/128 via 2001:DB8:3::2 dev veth-R2-R3


# --- On R3 ---
sudo ip netns exec R3 ip -6 route add fc00:1::1/128 via 2001:DB8:3::1 dev veth-R3-R2
sudo ip netns exec R3 ip -6 route add fc00:2::1/128 via 2001:DB8:3::1 dev veth-R3-R2
sudo ip netns exec R3 ip -6 route add fc00:4::1/128 via 2001:DB8:5::2 dev veth-R3-R5
sudo ip netns exec R3 ip -6 route add fc00:5::1/128 via 2001:DB8:5::2 dev veth-R3-R5


# --- On R4 ---
sudo ip netns exec R4 ip -6 route add fc00:1::1/128 via 2001:DB8:4::1 dev veth-R4-R1
sudo ip netns exec R4 ip -6 route add fc00:2::1/128 via 2001:DB8:4::1 dev veth-R4-R1
sudo ip netns exec R4 ip -6 route add fc00:3::1/128 via 2001:DB8:6::2 dev veth-R4-R5
sudo ip netns exec R4 ip -6 route add fc00:5::1/128 via 2001:DB8:6::2 dev veth-R4-R5

# --- On R5 ---
sudo ip netns exec R5 ip -6 route add fc00:1::1/128 via 2001:DB8:6::1 dev veth-R5-R4
sudo ip netns exec R5 ip -6 route add fc00:2::1/128 via 2001:DB8:5::1 dev veth-R5-R3
sudo ip netns exec R5 ip -6 route add fc00:3::1/128 via 2001:DB8:5::1 dev veth-R5-R3
sudo ip netns exec R5 ip -6 route add fc00:4::1/128 via 2001:DB8:6::1 dev veth-R5-R4

# Question 1 g) 
# Enable SRv6 and IPv6 forwarding on each router

for r in R1 R2 R3 R4 R5; do
    sudo ip netns exec $r sysctl -w net.ipv6.conf.all.forwarding=1
    sudo ip netns exec $r sysctl -w net.ipv6.conf.all.seg6_enabled=1
    sudo ip netns exec $r sysctl -w net.ipv6.conf.default.seg6_enabled=1
    
    # Enable on already created interfaces + Disable Reverse Path Filter of linux kernel
    for dev in $(sudo ip netns exec $r ls /sys/class/net/); do
        sudo ip netns exec $r sysctl -w net.ipv6.conf.$dev.seg6_enabled=1
        sudo ip netns exec $r sysctl -w net.ipv4.conf.$dev.rp_filter=0
    done
done

# Question 1 h)
# Define a routing rule for the router’s SID (End action) if packet dest. = router SID

sudo ip netns exec R1 ip -6 route add fc00:1::1/128 encap seg6local action End dev lo
sudo ip netns exec R2 ip -6 route add fc00:2::1/128 encap seg6local action End dev lo
sudo ip netns exec R3 ip -6 route add fc00:3::1/128 encap seg6local action End dev lo
sudo ip netns exec R4 ip -6 route add fc00:4::1/128 encap seg6local action End dev lo
sudo ip netns exec R5 ip -6 route add fc00:5::1/128 encap seg6local action End dev lo


# Question 1 i)
# Add SRv6 route on R1 - list of SIDs in reverse order of forwarding (R2 -> R3 -> R5 -> H2)

sudo ip netns exec R1 ip -6 route add 2001:DB8:7::/64 encap seg6 mode encap segs fc00:2::1,fc00:3::1,fc00:5::1 dev veth-R1-R2


# Same on R5 (R4 -> R1 -> H1)

sudo ip netns exec R5 ip -6 route add 2001:DB8:1::/64 encap seg6 mode encap segs fc00:4::1,fc00:1::1 dev veth-R5-R4

# Question 1 j)
# Testing the network connectivity

echo "Pinging..."
sudo ip netns exec H1 ping6 -c 5 2001:DB8:7::2

# Question 1 k)

# Array to store background Process IDs (PIDs)
PIDS=""

for r in R1 R2 R3 R4 R5; do
    # Run tcpdump inside the namespace
    # Parameters:
    # -i any : Listen on all interfaces
    # -w $r.pcap : Save to a file named R1.pcap, R2.pcap, ...
    # &: Run in background so the script continues
    sudo ip netns exec $r tcpdump -l -i any -w "${r}.pcap" &
    
    # Save the PID so we can kill it later
    PIDS="$PIDS $!"
done

# Give tcpdump a moment to initialize
sleep 2

# Ping again from H2 -> H2
echo "Pinging..."
sudo ip netns exec H1 ping6 -c 5 2001:DB8:7::2

echo "Stopping captures..."
sleep 1
# Kill all the background tcpdump processes
sudo kill $PIDS

echo "Captures saved to:"
ls -1 R*.pcap


# Question 1 l)
# Check if tshark is installed on the system
if ! command -v tshark; then
    echo "Error: tshark is not installed. Install it manually with: sudo apt install tshark"
    exit 1
fi

# Verify Forward Path (H1 -> H2)
# Echo Request must be seen to travel via R2 and R3
# Parameters:
# tshark -r: Reads the captured .pcap file (See task k)
# -Y "icmpv6.type == 128": Filters only for ICMPv6 Echo Requests (Type 128)
# 2>/dev/null: Silences tshark's technical warnings so they don't clutter the screen
# | wc -l: Counts the number of lines output (counts the matching packets)
CNT_R2_REQ=$(tshark -r R2.pcap -Y "icmpv6.type == 128" 2>/dev/null | wc -l)
CNT_R3_REQ=$(tshark -r R3.pcap -Y "icmpv6.type == 128" 2>/dev/null | wc -l)

# Verify Return Path (H2 -> H1)
# We expect the Echo Reply to travel via R4
# Filter for Echo Replies of Type 129
CNT_R4_REP=$(tshark -r R4.pcap -Y "icmpv6.type == 129" 2>/dev/null | wc -l)

# Verify Separation
# We have to ensure that traffic did not appear somewhere else

# R4 should NOT see the Request, Requests go via the top route (R2/R3)
CNT_R4_REQ=$(tshark -r R4.pcap -Y "icmpv6.type == 128" 2>/dev/null | wc -l)

# R2 should NOT see the Reply, Replies go via the bottom route (R4)
CNT_R2_REP=$(tshark -r R2.pcap -Y "icmpv6.type == 129" 2>/dev/null | wc -l)

# Final Logic Check
# Verify all conditions simultaneously using AND Operator (&&)
# Parameters:
# -gt 0: "Greater Than 0" -> Traffic MUST be present on the correct path
# -eq 0: "Equal to 0" -> Traffic MUST NOT be present on the wrong path
if [[ "$CNT_R2_REQ" -gt 0 && "$CNT_R3_REQ" -gt 0 && "$CNT_R4_REP" -gt 0 && "$CNT_R4_REQ" -eq 0 && "$CNT_R2_REP" -eq 0 ]]; then
    echo "Ok"
else
    echo "FAILED: Traffic did not strictly follow the SRv6 paths."
fi




