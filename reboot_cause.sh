reboot_cause.sh

#!/bin/bash
set -u

################################################################################################
################################################################################################
##                                                                                              ##
##       Name :     reboot_cause.sh    
##       Usage :                                                                                ##                                                                 
##       Version:   1.0   Latest                                                                 ##
##       Author :   Gurudatta N.R                                                                ##
##       MODIFIED   (MM/DD/YY) : 10/10/2024                                                   ##
##                                                                                              ##
##                                                                                              ##
#################################################################################################
#################################################################################################




LOGFILES="/var/log/syslog /var/log/messages /var/log/kern.log"

echo "==== Checking Recent Reboot Events ===="
last reboot | head

echo "==== Checking for Explicit Shutdown or Reboot Commands ===="
grep -Ei 'shutdown|reboot|halt|poweroff' $LOGFILES 2>/dev/null | tail -20

echo "==== Checking Kernel Panic or Critical Errors ===="
# Narrowed pattern - 'error'/'fatal' alone are too noisy on most distros
grep -Ei 'kernel panic|oops:|bug:|general protection fault|fatal exception' $LOGFILES 2>/dev/null | tail -20

echo "==== Checking for Out of Memory Events ===="
grep -Ei 'out of memory|killed process' $LOGFILES 2>/dev/null | tail -20

echo "==== Checking for Hardware Errors ===="
grep -Ei 'hardware error|mce|machine check' $LOGFILES 2>/dev/null | tail -20

echo "==== Checking IPMI/Console History for Errors ===="
# Filter the actual console history output, not an empty stdin
ipmitool sunoem cli 'show /HOST/console/history' 2>/dev/null \
  | grep -Ei 'hardware error|mce|machine check|hba|panic|fatal|oops' \
  | tail -20

echo "==== Checking for HBA Errors ===="
if [ -x /opt/MegaRAID/storcli/storcli64 ]; then
    /opt/MegaRAID/storcli/storcli64 -AdpEventLog -GetEvents -f /tmp/storcli64-GetEvents-all.out -aALL >/dev/null 2>&1
    grep -Ei 'hba|panic|fatal|oops' /tmp/storcli64-GetEvents-all.out 2>/dev/null | tail -20
else
    echo "storcli64 not found, skipping"
fi

echo "==== Uptime and Boot History ===="
uptime
who -b

echo "==== Last Logins ===="
last | head -10

echo "==== SYSTEM BOOT LOG (dmesg ring buffer) ===="
dmesg 2>/dev/null | grep -Ei 'reboot|shutdown|panic|oops' | tail -20

echo "==== SYSTEM BOOT LOG (/var/log/messages) ===="
grep -Ei 'reboot|shutdown|panic|oops' /var/log/messages 2>/dev/null | tail -20
