#!/bin/sh

RRD_WAIT=${RRD_WAIT:-2}
LANG=C

/root/rrdstats/cpu.pl
/bin/sleep $RRD_WAIT

/root/rrdstats/io.pl 2> /dev/null
/bin/sleep $RRD_WAIT

/root/rrdstats/memory.pl
/bin/sleep $RRD_WAIT

/root/rrdstats/network.pl
/bin/sleep $RRD_WAIT

/root/rrdstats/netstat.pl 2>&1 | fgrep -v 'error parsing /proc/net/snmp: Success'
/bin/sleep $RRD_WAIT

