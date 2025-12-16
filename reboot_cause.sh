reboot_cause.sh

#!/bin/bash

################################################################################################
################################################################################################
##                                                                                              ##
##       Name :     reboot_cause.sh    
##       Usage :                                                                                ##                                                                 
##       Version:  1.0   Latest                                                                 ##
##       Author : Gurudatta N.R                                                                ##
##       MODIFIED   (MM/DD/YY) : 10/10/2024                                                   ##
##                                                                                              ##
##                                                                                              ##
#################################################################################################
#################################################################################################

echo "==== Checking Recent Reboot Events ===="
last reboot | head

echo "==== Checking for Explicit Shutdown or Reboot Commands ===="
grep -Ei 'shutdown|reboot|halt|poweroff' /var/log/syslog /var/log/messages 2>/dev/null | tail -20

echo "==== Checking Kernel Panic or Critical Errors ===="
grep -Ei 'panic|error|fatal|oops' /var/log/syslog /var/log/messages /var/log/kern.log 2>/dev/null | tail -20

echo "==== Checking for Out of Memory Events ===="
grep -Ei 'Out of memory|Killed process' /var/log/syslog /var/log/messages /var/log/kern.log 2>/dev/null | tail -20

echo "==== Checking for Hardware Errors ===="
grep -Ei 'Hardware Error|MCE|Machine Check' /var/log/syslog /var/log/messages /var/log/kern.log 2>/dev/null | tail -20

echo "==== Checking for old console logs  ===="
ipmitool sunoem cli 'show /HOST/console/history' 2>/dev/null | tail -20
grep -Ei 'Hardware Error|MCE|Machine Check|HBA|panic|error|fatal|oops|'

echo "==== Checking for HBA  Errors ===="
/opt/MegaRAID/storcli/storcli64 -AdpEventLog -GetEvents -f >  /tmp/storcli64-GetEvents-all.out -aALL
grep -Ei 'HBA|panic|error|fatal|oops|' /tmp/storcli64-GetEvents-all.out 2>/dev/null | tail -20

echo "==== Uptime and Boot History ===="
uptime
who -b

echo "==== Last Logins ===="
last | head -10

echo "==== SYSTEM BOOT LOG ===="
dmesg | grep -Ei 'reboot|shutdown|panic|error|oops' /var/log/messages|  tail -20
