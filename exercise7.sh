#!/bin/bash

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

# --- BRING UP ALL INTERFACES BEFORE ROUTES ---
for ns in H1 H2 R1 R2 R3 R4 R5; do
    sudo ip netns exec $ns ip link set lo up
    for iface in $(sudo ip netns exec $ns ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//'); do
        if [[ $iface == veth* ]]; then
            sudo ip netns exec $ns ip link set dev $iface up
        fi
    done
done

# Optional tiny sleep to prevent race conditions
sleep 0.1

# H1 default route via R1
sudo ip netns exec H1 ip -6 route add default via 2001:DB8:1::2 dev veth-H1-R1

# H2 default route via R5
sudo ip netns exec H2 ip -6 route add default via 2001:DB8:7::1 dev veth-H2-R5

# Test via 'sudo ip netns exec H2 ping6 -c 3 2001:DB8:7::1' and 'sudo ip netns exec H1 ping6 -c 3 2001:DB8:1::2'

# Question 1 e) 
# Assign loopback interfaces to routers: 

sudo ip netns exec R1 ip -6 addr add fc00:1::1/128 dev lo
sudo ip netns exec R2 ip -6 addr add fc00:2::1/128 dev lo
sudo ip netns exec R3 ip -6 addr add fc00:3::1/128 dev lo
sudo ip netns exec R4 ip -6 addr add fc00:4::1/128 dev lo
sudo ip netns exec R5 ip -6 addr add fc00:5::1/128 dev lo

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
sudo ip netns exec R5 ip -6 route add fc00:1::1/128 via 2001:DB8:5::1 dev veth-R5-R3
sudo ip netns exec R5 ip -6 route add fc00:2::1/128 via 2001:DB8:5::1 dev veth-R5-R3
sudo ip netns exec R5 ip -6 route add fc00:3::1/128 via 2001:DB8:5::1 dev veth-R5-R3
sudo ip netns exec R5 ip -6 route add fc00:4::1/128 via 2001:DB8:6::1 dev veth-R5-R4

# Test router ip with 'sudo ip netns exec R1 ip -6 route show'
# and SID connectivity with: 'sudo ip netns exec R1 ping6 -c 3 fc00:2::1'
# and 'sudo ip netns exec R3 ping6 -c 3 fc00:5::1'

# Question 1 g) 
# Enable SRv6 and IPv6 forwarding on each router

for r in R1 R2 R3 R4 R5; do
    sudo ip netns exec $r sysctl -w net.ipv6.conf.all.forwarding=1
    sudo ip netns exec $r sysctl -w net.ipv6.conf.all.seg6_enabled=1
done

# Question 1 h)
# Define a routing rule for the router’s SID (End action) if packet dest. = router SID

sudo ip netns exec R1 ip -6 route add fc00:1::1/128 dev lo encap seg6local action End
sudo ip netns exec R2 ip -6 route add fc00:2::1/128 dev lo encap seg6local action End
sudo ip netns exec R3 ip -6 route add fc00:3::1/128 dev lo encap seg6local action End
sudo ip netns exec R4 ip -6 route add fc00:4::1/128 dev lo encap seg6local action End
sudo ip netns exec R5 ip -6 route add fc00:5::1/128 dev lo encap seg6local action End


# Question 1 i)
# Add SRv6 route on R1 - list of SIDs in reverse order of forwarding (R2 -> R3 -> R5 -> H2)

sudo ip netns exec R1 ip -6 route add 2001:DB8:7::/64 encap seg6 mode encap segs fc00:2::1,fc00:3::1,fc00:5::1 dev veth-R1-R2


# Same on R5 (R4 -> R1 -> H1)

sudo ip netns exec R5 ip -6 route add 2001:DB8:1::/64 encap seg6 mode encap segs fc00:4::1,fc00:1::1 dev veth-R5-R4

# Question 1 j)



# Ping from H1 to H2 to test conectivity
sudo ip netns exec H1 ping6 -c 5 2001:DB8:7::2













