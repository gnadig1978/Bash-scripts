exadata_DB_KVM_health_check.sh

#!/bin/bash

# Script: exadata_DB_KVM_health_check.sh
# Purpose: Collect system diagnostics and Exadata hardware health summary
# Usage: bash exadata_DB_KVM_health_check.sh > exadata_health_$(hostname).log
# Written by Gurudatta N.R

# Colors
RED='\033[1;31m'
NC='\033[0m' # No Color

SEPARATOR="---------------"

print_section() {
    echo ""
    echo -e "${RED}$1${NC}"
    echo "$SEPARATOR"
}

# Host & System Basics
print_section "Hostname"
hostname

print_section "Uptime"
uptime

print_section "Timestamp"
date

print_section "Kernel Version"
uname -r

print_section "OS Release"
cat /etc/*release | grep -Ei 'name|version'

print_section "Imageinfo"
imageinfo

print_section "Dmidecode"
dmidecode -t1

# Infiniband
print_section "ibstat"
ibstat

# Virtualization
if command -v virsh &> /dev/null; then
    print_section "Virsh List"
    virsh list --all
else
    print_section "Virsh List"
    echo "virsh not available"
fi

# Alerts & Logs
if command -v dbmcli &> /dev/null; then
    print_section "Alerthistory (Network Only)"
    dbmcli -e list alerthistory | grep -v AIDE | grep -i Network
else
    print_section "Alerthistory (Network Only)"
    echo "dbmcli not found in PATH"
fi

print_section "OS Messages (MCE)"
grep -i mce /var/log/messages | tail -20

# Memory Info
print_section "MemTotal"
grep MemTotal /proc/meminfo

# CPU Info
print_section "CPU Info"
lscpu | grep -E 'Model name|Socket|CPU\(s\)'

# Disk Usage
print_section "Disk Usage"
df -hT | grep -v tmpfs

# Disks
print_section "Physical Disks"
dbmcli -e 'list physicaldisk'

print_section "BBU"
if [ -x /opt/MegaRAID/storcli/storcli64 ]; then
    /opt/MegaRAID/storcli/storcli64 -adpbbucmd -aALL
else
    echo "BBU check tool not found: /opt/MegaRAID/storcli/storcli64"
fi

# IPMI Fault Management
print_section "Show Faulty"
ipmitool sunoem cli 'show faulty' 2>/dev/null || echo "IPMI command failed"

print_section "Open Problems"
ipmitool sunoem cli 'show /system/open_problems' 2>/dev/null || echo "IPMI command failed"

print_section "Fmadm Faulty"
ipmitool sunoem cli 'start /SP/faultmgmt/shell' 'y' 'fmadm faulty' 2>/dev/null || echo "IPMI command failed"

# Link Errors
print_section "Dmesg Output (Link-related)"
dmesg -T | grep -i link | tail -20

# Network Interfaces
print_section "Active Interfaces and IPs"
ip -o -4 addr show up | awk '{print $2, $4}'

print_section "Interface Details (eth1 & eth2)"
ip a s | grep -E 'eth1|eth2'

print_section "Bond Details Interface Details"
cat /proc/net/bonding/bondeth0 2>/dev/null || echo "bondeth0 not found"

print_section "Eth1 Link Speed"
ethtool eth1 | egrep 'Settings for|Link detected|Speed|Duplex' 2>/dev/null || echo "eth1 not found"

print_section "Eth2 Link Speed"
ethtool eth2 | egrep 'Settings for|Link detected|Speed|Duplex' 2>/dev/null || echo "eth2 not found"

echo -e "\nEFI Boot Manager Output\n---------------"
/usr/sbin/efibootmgr -v

print_section "re0"
/opt/oracle.SupportTools/ibdiagtools/utils/lldp_cap.py re0

print_section "re1"
/opt/oracle.SupportTools/ibdiagtools/utils/lldp_cap.py re1

print_section "sfrules all"
/opt/oracle.SupportTools/sfrules all

# Extra DBMCLI
print_section "DBMCLI Disk Details"
dbmcli -e list dbserver detail

print_section "dbserver validate"
dbmcli -e alter dbserver validate configuration


