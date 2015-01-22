#!/usr/bin/perl
#
# RRD script to display cpu usage
# 2003,2011 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
use strict;
use warnings;
use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my @datafile = ("$conf{DBPATH}/cpu0.rrd", "$conf{DBPATH}/cpu1.rrd");
my $picbase   = "$conf{OUTPATH}/cpu-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

for my $cpu ( qw(0) ) {

    # generate database if absent
    if ( ! -e $datafile[$cpu] ) {
        RRDs::create($datafile[$cpu],
            "DS:user:COUNTER:600:0:101",
            "DS:nice:COUNTER:600:0:101",
            "DS:system:COUNTER:600:0:101",
            "DS:idle:COUNTER:600:0:101",
            "DS:iowait:COUNTER:600:0:101",
            "DS:hw_irq:COUNTER:600:0:101",
            "DS:sw_irq:COUNTER:600:0:101",
            "RRA:AVERAGE:0.5:1:600",
            "RRA:AVERAGE:0.5:6:700",
            "RRA:AVERAGE:0.5:24:775",
            "RRA:AVERAGE:0.5:288:797"
        );
        $ERR=RRDs::error;
        die "ERROR while creating $datafile[$cpu]: $ERR\n" if $ERR;
        print "created $datafile[$cpu]\n";
    }

    # get cpu usage
    open PROC, "<", "/proc/stat" or die "can't open /proc/stat: $!\n";
    my $cpuline;
    while ($cpuline = <PROC>) {
        last if $cpuline =~ /^cpu$cpu /;
    }
    close PROC or die "can't close /proc/stat: $!\n";

    chomp $cpuline;
    my (undef, $user, $nice, $system, $idle, $iowait, $hw_irq, $sw_irq) = split /\s+/, $cpuline;
    $iowait = 0 unless defined $iowait;
    $hw_irq = 0 unless defined $hw_irq;
    $sw_irq = 0 unless defined $sw_irq;

    # update database
    RRDs::update($datafile[$cpu],"N:${user}:${nice}:${system}:${idle}:${iowait}:${hw_irq}:${sw_irq}");
    $ERR=RRDs::error;
    die "ERROR while updating $datafile[$cpu]: $ERR\n" if $ERR;

}

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
        "--start=-${time}",
        '--lazy',
        '--imgformat=PNG',
        "--title=${hostname} cpu usage (last $scale)",

        "-c","BACK#FF000000",
        "-c","CANVAS#FFFFFF00",
        "-c","SHADEA#FF000000",
        "-c","SHADEB#FF000000",

        "--border=0",
        '--base=1024',
        "--width=$conf{GRAPH_WIDTH}",
        "--height=$conf{GRAPH_HEIGHT}",
        '--lower-limit=0',
#        '--upper-limit=100',
        '--rigid',

        "DEF:user0=${datafile[0]}:user:AVERAGE",
        "DEF:nice0=${datafile[0]}:nice:AVERAGE",
        "DEF:system0=${datafile[0]}:system:AVERAGE",
        "DEF:idle0=${datafile[0]}:idle:AVERAGE",
        "DEF:iowait0=${datafile[0]}:iowait:AVERAGE",
        "DEF:hw_irq0=${datafile[0]}:hw_irq:AVERAGE",
        "DEF:sw_irq0=${datafile[0]}:sw_irq:AVERAGE",

        'CDEF:total0=0,user0,+,nice0,+,system0,+,iowait0,+,hw_irq0,+,sw_irq0,+',

        'AREA:user0#FF0000:user',
        'STACK:nice0#FFC000:nice',
        'STACK:system0#FFFF00:system',
        'STACK:iowait0#92D050:iowait',
        'STACK:hw_irq0#00B0F0:hw_irq',
        'STACK:sw_irq0#7030A0:sw_irq',
        'LINE:total0#000000:total',
        'COMMENT:\n',
        'COMMENT: ',
    );
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile[0]/$datafile[1] $time: $ERR\n" if $ERR;
}
