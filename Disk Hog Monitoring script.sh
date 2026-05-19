#!/bin/bash

################################################################################################
################################################################################################
##                                                                                              ##
##       Name :    Disk Hog Monitoring Script       
##       Usage :                                                                                ##                                                                 
##       Version:  1.0   Latest                                                                 ##
##       Author : Gurudatta N.R                                                                ##
##       MODIFIED   (MM/DD/YY) : 10/10/2024                                                   ##
##                                                                                              ##
##                                                                                              ##
#################################################################################################
#################################################################################################


HOSTNAME=$(hostname)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Email details
TO_EMAIL="gurudatta.nadig@gmail.com"
FROM_EMAIL="gurudatta.nadig@gmail.com"
SUBJECT="Disk Usage Alert on $HOSTNAME"

# Temporary report file
REPORT="/tmp/disk_hog_report.txt"

# Threshold percentage
THRESHOLD=80

# Filesystem usage check
USAGE=$(df -h / | awk 'NR==2 {gsub("%",""); print $5}')

echo "Disk Usage Report - $HOSTNAME" > $REPORT
echo "Generated on: $DATE" >> $REPORT
echo "----------------------------------------" >> $REPORT
echo "" >> $REPORT

echo "Current Disk Usage:" >> $REPORT
df -h >> $REPORT

echo "" >> $REPORT
echo "Top 20 Disk Hogs under / :" >> $REPORT
echo "----------------------------------------" >> $REPORT

du -ahx / 2>/dev/null | sort -rh | head -20 >> $REPORT

# Send email only if threshold exceeded
if [ "$USAGE" -ge "$THRESHOLD" ]; then
    mail -s "$SUBJECT" "$TO_EMAIL" < $REPORT
fi

# Cleanup
rm -f $REPORT
