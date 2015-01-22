#!/usr/bin/perl
#
# RRD script to display nginx connections/requests
# 2003,2011 (c) by Stiks <stiks@yn.ee>
# Licensed under GNU GPL.
#
# This script should be run every minute
#

use strict;
use warnings;
use RRDs;
use LWP::UserAgent;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/nginx.rrd";
my $picbase  = "$conf{OUTPATH}/nginx-";

my $URL = "http://127.0.0.1:8080/nginx_status";


# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    RRDs::create($datafile,
        "-s 60",
        "DS:requests:COUNTER:120:0:100000000",
        "DS:total:ABSOLUTE:120:0:60000",
        "DS:reading:ABSOLUTE:120:0:60000",
        "DS:writing:ABSOLUTE:120:0:60000",
        "DS:waiting:ABSOLUTE:120:0:60000",

        "RRA:AVERAGE:0.5:1:2880",
        "RRA:AVERAGE:0.5:30:672",
        "RRA:AVERAGE:0.5:120:732",
        "RRA:AVERAGE:0.5:720:1460"
    );
    $ERR=RRDs::error;
    die "ERROR while creating $datafile: $ERR\n" if $ERR;
    print "created $datafile\n";
}

my $ua = LWP::UserAgent->new(timeout => 30);
my $response = $ua->request(HTTP::Request->new('GET', $URL));

my $requests = 0;
my $total   = 0;
my $reading = 0;
my $writing = 0;
my $waiting = 0;

foreach (split(/\n/, $response->content)) {
    $total = $1 if (/^Active connections:\s+(\d+)/);
    if (/^Reading:\s+(\d+).*Writing:\s+(\d+).*Waiting:\s+(\d+)/) {
        $reading = $1;
        $writing = $2;
        $waiting = $3;
    }

    $requests = $3 if (/^\s+(\d+)\s+(\d+)\s+(\d+)/);
}

# update database
RRDs::update($datafile, "N:$requests:$total:$reading:$writing:$waiting");
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase.$scale.".png",
        "--start=-${time}",
        '--lazy',
        '--imgformat=PNG',
        "--border=0",

        "-c","BACK#FF000000",
        "-c","CANVAS#FFFFFF00",
        "-c","SHADEA#FF000000",
        "-c","SHADEB#FF000000",

        "--title=${hostname} nginx connections (last $scale)",
        '--base=1024',
        "--width=$conf{GRAPH_WIDTH}",
        "--height=$conf{GRAPH_HEIGHT}",

        "DEF:total=${datafile}:total:AVERAGE",
        "DEF:reading=${datafile}:reading:AVERAGE",
        "DEF:writing=${datafile}:writing:AVERAGE",
        "DEF:waiting=${datafile}:waiting:AVERAGE",
        "DEF:requests=${datafile}:requests:AVERAGE",

        "CDEF:requests_x=0,requests,-",

        "AREA:waiting#CD2626AA:Waiting",
        "STACK:writing#00688BAA:Writing",
        "STACK:reading#228B22AA:Reading",
        "AREA:requests_x#32CD32:Requests",
        "LINE1:requests_x#336600",
    );

    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
