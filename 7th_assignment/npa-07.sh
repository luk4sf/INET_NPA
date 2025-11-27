#!/bin/bash

if [[ $1 == "clear" ]]; then
    for ns in H1 H2 R1 R2 R3 R4 R5; do
        sudo ip netns delete $ns 2>/dev/null
    done
    echo "All namespaces deleted."
    exit 0
fi

# (a) Namespaces
for ns in H1 H2 R1 R2 R3 R4 R5; do
    sudo ip netns add $ns
done

# (b) Links
create_link() {
    sudo ip link add "veth-$1-$2" type veth peer name "veth-$2-$1"
    sudo ip link set "veth-$1-$2" netns $1
    sudo ip link set "veth-$2-$1" netns $2
    # Set link up immediately
    sudo ip netns exec $1 ip link set "veth-$1-$2" up
    sudo ip netns exec $2 ip link set "veth-$2-$1" up
}
create_link H1 R1
create_link R1 R2
create_link R1 R4
create_link R2 R3
create_link R3 R5
create_link R5 R4
create_link R5 H2

# Bring up Loopbacks
for ns in H1 H2 R1 R2 R3 R4 R5; do
    sudo ip netns exec $ns ip link set lo up
done

# (c) Addressing
sudo ip netns exec H1 ip -6 addr add 2001:DB8:1::1/64 dev veth-H1-R1
sudo ip netns exec R1 ip -6 addr add 2001:DB8:1::2/64 dev veth-R1-H1
sudo ip netns exec R1 ip -6 addr add 2001:DB8:2::1/64 dev veth-R1-R2
sudo ip netns exec R2 ip -6 addr add 2001:DB8:2::2/64 dev veth-R2-R1
sudo ip netns exec R2 ip -6 addr add 2001:DB8:3::1/64 dev veth-R2-R3
sudo ip netns exec R3 ip -6 addr add 2001:DB8:3::2/64 dev veth-R3-R2
sudo ip netns exec R3 ip -6 addr add 2001:DB8:5::1/64 dev veth-R3-R5
sudo ip netns exec R5 ip -6 addr add 2001:DB8:5::2/64 dev veth-R5-R3
sudo ip netns exec R1 ip -6 addr add 2001:DB8:4::1/64 dev veth-R1-R4
sudo ip netns exec R4 ip -6 addr add 2001:DB8:4::2/64 dev veth-R4-R1
sudo ip netns exec R4 ip -6 addr add 2001:DB8:6::1/64 dev veth-R4-R5
sudo ip netns exec R5 ip -6 addr add 2001:DB8:6::2/64 dev veth-R5-R4
sudo ip netns exec R5 ip -6 addr add 2001:DB8:7::1/64 dev veth-R5-H2
sudo ip netns exec H2 ip -6 addr add 2001:DB8:7::2/64 dev veth-H2-R5

# (d) Host Routes
sudo ip netns exec H1 ip -6 route add default via 2001:DB8:1::2
sudo ip netns exec H2 ip -6 route add default via 2001:DB8:7::1

# (e) Router SIDs
sudo ip netns exec R1 ip -6 addr add fc00:1::1/128 dev lo
sudo ip netns exec R2 ip -6 addr add fc00:2::1/128 dev lo
sudo ip netns exec R3 ip -6 addr add fc00:3::1/128 dev lo
sudo ip netns exec R4 ip -6 addr add fc00:4::1/128 dev lo
sudo ip netns exec R5 ip -6 addr add fc00:5::1/128 dev lo

# (g) Enable SRv6 & Forwarding (Moved UP before routes to be safe)
# Also disable RP_Filter here to allow asymmetric return traffic
for r in R1 R2 R3 R4 R5; do
    sudo ip netns exec $r sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
    sudo ip netns exec $r sysctl -w net.ipv6.conf.all.seg6_enabled=1 >/dev/null
    sudo ip netns exec $r sysctl -w net.ipv6.conf.default.seg6_enabled=1 >/dev/null
    
    # Enable on specific interfaces + Disable RP Filter
    for dev in $(sudo ip netns exec $r ls /sys/class/net/); do
        sudo ip netns exec $r sysctl -w net.ipv6.conf.$dev.seg6_enabled=1 2>/dev/null
        sudo ip netns exec $r sysctl -w net.ipv4.conf.$dev.rp_filter=0 2>/dev/null
    done
done

# (f) Routes (Underlay)
# R1
sudo ip netns exec R1 ip -6 route add fc00:2::1/128 via 2001:DB8:2::2
sudo ip netns exec R1 ip -6 route add fc00:3::1/128 via 2001:DB8:2::2
sudo ip netns exec R1 ip -6 route add fc00:4::1/128 via 2001:DB8:4::2
sudo ip netns exec R1 ip -6 route add fc00:5::1/128 via 2001:DB8:4::2 # Via R4 (Bottom)

# R2
sudo ip netns exec R2 ip -6 route add fc00:1::1/128 via 2001:DB8:2::1
sudo ip netns exec R2 ip -6 route add fc00:3::1/128 via 2001:DB8:3::2
sudo ip netns exec R2 ip -6 route add fc00:4::1/128 via 2001:DB8:2::1
sudo ip netns exec R2 ip -6 route add fc00:5::1/128 via 2001:DB8:3::2

# R3
sudo ip netns exec R3 ip -6 route add fc00:1::1/128 via 2001:DB8:3::1
sudo ip netns exec R3 ip -6 route add fc00:2::1/128 via 2001:DB8:3::1
sudo ip netns exec R3 ip -6 route add fc00:4::1/128 via 2001:DB8:5::2
sudo ip netns exec R3 ip -6 route add fc00:5::1/128 via 2001:DB8:5::2

# R4
sudo ip netns exec R4 ip -6 route add fc00:1::1/128 via 2001:DB8:4::1
sudo ip netns exec R4 ip -6 route add fc00:2::1/128 via 2001:DB8:4::1
sudo ip netns exec R4 ip -6 route add fc00:3::1/128 via 2001:DB8:6::2
sudo ip netns exec R4 ip -6 route add fc00:5::1/128 via 2001:DB8:6::2

# R5 [FIXED RETURN PATH HERE]
# Route to R1 goes via R4 (Bottom), not R3
sudo ip netns exec R5 ip -6 route add fc00:1::1/128 via 2001:DB8:6::1 
sudo ip netns exec R5 ip -6 route add fc00:2::1/128 via 2001:DB8:5::1
sudo ip netns exec R5 ip -6 route add fc00:3::1/128 via 2001:DB8:5::1
sudo ip netns exec R5 ip -6 route add fc00:4::1/128 via 2001:DB8:6::1

# (h) Local End Behavior
sudo ip netns exec R1 ip -6 route add fc00:1::1/128 encap seg6local action End dev lo
sudo ip netns exec R2 ip -6 route add fc00:2::1/128 encap seg6local action End dev lo
sudo ip netns exec R3 ip -6 route add fc00:3::1/128 encap seg6local action End dev lo
sudo ip netns exec R4 ip -6 route add fc00:4::1/128 encap seg6local action End dev lo
sudo ip netns exec R5 ip -6 route add fc00:5::1/128 encap seg6local action End dev lo

# (i) SR Policies
# R1 -> R2 -> R3 -> R5 -> H2
sudo ip netns exec R1 ip -6 route add 2001:DB8:7::/64 encap seg6 mode encap segs fc00:2::1,fc00:3::1,fc00:5::1 dev veth-R1-R2
# R5 -> R4 -> R1 -> H1
sudo ip netns exec R5 ip -6 route add 2001:DB8:1::/64 encap seg6 mode encap segs fc00:4::1,fc00:1::1 dev veth-R5-R4

# (j) Test
echo "Waiting 3 seconds for DAD and NDP..."
sleep 3
echo "Pinging..."
sudo ip netns exec H1 ping6 -c 5 2001:DB8:7::2
