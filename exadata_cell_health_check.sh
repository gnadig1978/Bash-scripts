#!/usr/bin/bash
################################################################################################
################################################################################################
##                                                                                              ##
##       Name :    exadata_cell_health_check.sh        
##       Usage :                                                                                ##                                                                 
##       Version:  1.0   Latest                                                                 ##
##       Author : Gurudatta N.R                                                                ##
##       MODIFIED   (MM/DD/YY) : 10/10/2024                                                   ##
##                                                                                              ##
##                                                                                              ##
#################################################################################################
#################################################################################################
LOGFILE="exadata_health_report_$(date +%F_%H%M%S).log"

exec > >(tee -a "$LOGFILE") 2>&1

print_section() {
    echo ""
    echo "$1"
    echo "***************"
}

print_section "Hostname"
hostname

print_section "Uptime"
uptime

print_section "Imageinfo"
imageinfo

print_section "Cell Services"
cellcli -e list cell detail | egrep 'cellsrvStatus|msStatus|rsStatus'

print_section "Dmidecode"
dmidecode -t1

print_section "Dmesg Output (Link-related)"
dmesg -T | grep -i link | tail -20

print_section "Alerthistory"
cellcli -e "list alerthistory detail" | tail -30
print_section "Physicaldisk Status"
cellcli -e list physicaldisk

print_section "Flashdisk Status"
cellcli -e list physicaldisk where diskType='FlashDisk'

print_section "Failed Disk"
cellcli -e list physicaldisk where status !=normal detail

print_section "Griddisk Status"
cellcli -e list griddisk attributes name, status,asmModeStatus,asmdeactivationoutcome,size

print_section "Diskmap"
cellcli -e list diskmap

print_section "FlashCacheMode"
cellcli -e list cell attributes name,flashCacheMode

print_section "FlashCache Detail"
cellcli -e list flashcache detail

print_section "FlashLog Detail"
cellcli -e list flashlog detail

print_section "Griddisk Cache"
cellcli -e list griddisk attributes name,cachedby

print_section "Hardware fault status"
ipmitool sunoem cli "show -l all /SYS fault_state==Faulted"


print_section "griddisk attributes name, status, asmDiskgroupName, asmDiskName, asmModeStatus, availableTo,size, asmDeactivationOutcome "
cellcli -e list griddisk attributes name, status, asmDiskgroupName, asmDiskName, asmModeStatus, availableTo,size, asmDeactivationOutcome |grep -i SYNCING

print_section "Interface Stats"
ip -br a

# IPMI Fault Management
print_section "Show Faulty"
ipmitool sunoem cli 'show faulty'

print_section "Open Problems"
ipmitool sunoem cli 'show /system/open_problems'

print_section "Fmadm Faulty"
ipmitool sunoem cli 'start /SP/faultmgmt/shell' 'y' 'fmadm faulty'

#echo -e "\nIPMI - PCI Add-on Devices\n---------------"
#ipmitool sunoem cli "show -l all -d properties /System/PCI_Devices/Add-on"

#echo -e "\nIPMI - Current Host Console\n---------------"
#ipmitool sunoem cli "show /HOST/console"

#echo -e "\nIPMI - Host Console History\n---------------"
#ipmitool sunoem cli "show /HOST/console/history"

print_section "Switch Stats"

/opt/oracle.SupportTools/ibdiagtools/utils/lldp_cap.py re0pf
/opt/oracle.SupportTools/ibdiagtools/utils/lldp_cap.py re1pf

 # Extra CellCLI
print_section "cellcli Details"
cellcli -e list cell detail

print_section "cell validate"
cellcli -e alter cell validate configuration;



echo ""
echo "Health report saved to $LOGFILE"
