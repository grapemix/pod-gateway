#!/bin/bash

# hostname of the gateway - it must accept vxlan and DHCP traffic
# clients get it as env variable
GATEWAY_NAME="$gateway"
# K8S DNS IP address
# clients get it as env variable
K8S_DNS_IPS="$K8S_DNS_ips"
# Blank  sepated IPs not sent to the POD gateway but to the default K8S
# This is needed, for example, in case your CNI does
# not add a non-default rule for the K8S addresses (Flannel does)
NOT_ROUTED_TO_GATEWAY_CIDRS=""

# Vxlan ID to use
VXLAN_ID="42"
# Vxlan Port to use, change it to 4789 (preferably) when using Cillium
VXLAN_PORT="0"

# NEW: Optional CIDR notation for flexible network sizes (e.g., "172.16.0.0/16")
VXLAN_NETWORK_CIDR="${VXLAN_NETWORK_CIDR:-}"

# Calculate network parameters based on configuration
if [[ -n "$VXLAN_NETWORK_CIDR" ]]; then
    # Parse CIDR notation
    VXLAN_NETWORK_BASE="${VXLAN_NETWORK_CIDR%/*}"
    VXLAN_PREFIX="${VXLAN_NETWORK_CIDR#*/}"
    
    # Extract network portion for compatibility and calculate gateway
    IFS='.' read -r o1 o2 o3 o4 <<< "$VXLAN_NETWORK_BASE"
    if [[ $VXLAN_PREFIX -ge 24 ]]; then
        VXLAN_IP_NETWORK="${o1}.${o2}.${o3}"
        VXLAN_GATEWAY_IP="${o1}.${o2}.${o3}.1"
        VXLAN_DHCP_END="255"
    elif [[ $VXLAN_PREFIX -ge 16 ]]; then
        VXLAN_IP_NETWORK="${o1}.${o2}"
        VXLAN_GATEWAY_IP="${o1}.${o2}.0.1"
        VXLAN_DHCP_END="255.255"
    else
        VXLAN_IP_NETWORK="${o1}"
        VXLAN_GATEWAY_IP="${o1}.0.0.1"
        VXLAN_DHCP_END="255.255.255"
    fi
else
    # Legacy mode: /24 network (backward compatibility)
    VXLAN_PREFIX="24"
    VXLAN_GATEWAY_IP="${VXLAN_IP_NETWORK}.1"
    VXLAN_DHCP_END="255"
fi

VXLAN_GATEWAY_FIRST_DYNAMIC_IP=20

# If using a VPN, interface name created by it
VPN_INTERFACE=tun0
# Prevent non VPN traffic to leave the gateway
VPN_BLOCK_OTHER_TRAFFIC=true
# If VPN_BLOCK_OTHER_TRAFFIC is true, allow VPN traffic over this port
VPN_TRAFFIC_PORT=443
# Traffic to these IPs will be send through the K8S gateway
VPN_LOCAL_CIDRS="10.0.0.0/8 192.168.0.0/16"

# DNS queries to these domains will be resolved by K8S DNS instead of
# the default (typcally the VPN client changes it)
DNS_LOCAL_CIDRS="local"
# Dns to use for local resolution, if unset, will use default resolv.conf
DNS_LOCAL_SERVER=

# dnsmasq monitors directories. /etc/resolv.conf in a container is in another
# file system so it does not work. To circumvent this a copy is made using
# inotifyd
RESOLV_CONF_COPY=/etc/resolv_copy.conf

# ICMP heartbeats are used to ensure the pod-gateway is connectable from the clients.
# The following value can be used to to provide more stability in an unreliable network connection.
CONNECTION_RETRY_COUNT=1

# you want to disable DNSSEC with the gateway then set this to false
GATEWAY_ENABLE_DNSSEC=true

# If you use nftables for iptables you need to set this to yes
IPTABLES_NFT=no

# Set to WAN/VPN IP to enable SNAT instead of Masquerading
SNAT_IP=""

# Set the VPN MTU. It also adjust the VXLAN MTU to avoid fragmenting the package in the gateway (VXLAN-> MTU)
VPN_INTERFACE_MTU=""
