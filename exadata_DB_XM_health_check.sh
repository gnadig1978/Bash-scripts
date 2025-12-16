exadata_DB_XM_health_check.sh

#!/bin/bash

# Script: exadata_DB_XM_health_check.sh
# Purpose: Collect system diagnostics and Exadata hardware health summary
# Usage: bash exadata_DB_XM_health_check.sh> exadata_health_$(hostname).log
# Written by Gurudatta N.R

SEPARATOR="---------------"

print_section() {
    echo ""
    echo "$1"
    echo "$SEPARATOR"
}

# Host & System Basics
print_section "Hostname"
hostname

print_section "Uptime"
uptime

print_section "Imageinfo"
imageinfo

print_section "Dmidecode"
dmidecode -t1

# Infiniband
print_section "ibstat"
ibstat

# Virtualization
print_section "xm List"
xm list 

# Alerts & Logs
print_section "Alerthistory (Network Only)"
dbmcli -e list alerthistory | grep -v AIDE | grep -i Network

print_section "OS Messages (MCE)"
grep -i mce /var/log/messages | tail -20

# Memory Info
print_section "MemTotal"
grep MemTotal /proc/meminfo


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
ipmitool sunoem cli 'show faulty'

print_section "Open Problems"
ipmitool sunoem cli 'show /system/open_problems'

print_section "Fmadm Faulty"
ipmitool sunoem cli 'start /SP/faultmgmt/shell' 'y' 'fmadm faulty'

# Link Errors
print_section "Dmesg Output (Link-related)"
dmesg -T | grep -i link | tail -20

# Network Interfaces
print_section "Interface Details (eth1 & eth2)"
ip a s | grep -E 'eth1|eth2'

# Network Interfaces
print_section "Bond Details Interface Details "
cat /proc/net/bonding/bondeth0

print_section "Eth1 Link Speed"
ethtool eth1 | egrep 'Settings for|Link detected|Speed|Duplex'

print_section "Eth2 Link Speed"
ethtool eth2 | egrep 'Settings for|Link detected|Speed|Duplex'

echo -e "\nEFI Boot Manager Output\n---------------"
/usr/sbin/efibootmgr -v


# Extra DBMCLI
print_section "DBMCLI Disk Details"
dbmcli -e list dbserver  detail

print_section "dbserver validate"
dbmcli -e alter dbserver validate configuration
