#!/usr/bin/perl
#
# RRD script to display memory usage
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
my $datafile = "$conf{DBPATH}/varnish.rrd";
my $picbase  = "$conf{OUTPATH}/varnish-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 3G/5G for each value
    RRDs::create($datafile,
		"-s 60",
		# metrics
		"DS:cache_hit:GAUGE:600:0:3000000000",		# MAIN.cache_hit
		"DS:cache_hitpass:GAUGE:600:0:3000000000",	# MAIN.cache_hitpass
		"DS:cache_miss:GAUGE:600:0:3000000000",		# MAIN.cache_miss

		"DS:cache_ratio:GAUGE:600:0:3000000000",

		"DS:client_req:GAUGE:600:0:3000000000",		# MAIN.client_req

		"DS:req_bytes:GAUGE:600:0:8000000000",		# MAIN.s_req_hdrbytes + MAIN.s_req_bodybytes
		"DS:resp_bytes:GAUGE:600:0:8000000000",		# MAIN.s_resp_hdrbytes + MAIN.s_resp_bodybytes

		"RRA:AVERAGE:0.5:1:600",
		"RRA:AVERAGE:0.5:6:700",
		"RRA:AVERAGE:0.5:24:775",
		"RRA:AVERAGE:0.5:288:797"


#		"RRA:MAX:0.5:1:600",
#		"RRA:MAX:0.5:6:700",
#		"RRA:MAX:0.5:24:775",
#		"RRA:MAX:0.5:288:797"

	);
    $ERR=RRDs::error;
    die "ERROR while creating $datafile: $ERR\n" if $ERR;
    print "created $datafile\n";
}

my ($cache_hit, $cache_hitpass, $cache_miss, $cache_ratio, $client_req);
my $req_bytes  = 0; 
my $resp_bytes = 0;

sub get_stat {
	my $result = qx(/usr/bin/varnishstat -1 -f MAIN);
	my @ans = split (/\n/s, $result);

#	print $result." \n";

	my $line;
	my ($name, $total, $real);
	foreach $line (@ans) {
    	($name, $total, $real) = split /\s+/, $line;

    	# replace MAIN. in name
		$name =~ s/MAIN.//g;
    	if ($name eq "cache_hit") {
    		$cache_hit = $real;
    	} elsif ($name eq "cache_hitpass") {
    		$cache_hitpass = $real;
    	} elsif ($name eq "cache_miss") {
    		$cache_miss = $real;
    	} elsif ($name eq "client_req") {
    		$client_req = $real;
    	} elsif (($name eq "s_req_hdrbytes") or ($name eq "s_req_bodybytes")) {
    		$req_bytes += $real;
    	} elsif (($name eq "s_resp_hdrbytes") or ($name eq "s_resp_bodybytes")) {
    		$resp_bytes += $real;
    	}

#		print "-> ".$name." : ".$total." : ".$real."\n";
	}
}

get_stat();

if ($client_req == 0) {
    $cache_ratio = 0;
} else {
    $cache_ratio = ($cache_miss / $client_req) * 100;
}

# update database
RRDs::update($datafile, "N:${cache_hit}:${cache_hitpass}:${cache_miss}:${cache_ratio}:${client_req}:${req_bytes}:${resp_bytes}");
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

		"--title=${hostname} varnish cache (last $scale)",
		'--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",

		"DEF:cache_hit=${datafile}:cache_hit:AVERAGE",
		"DEF:cache_hitpass=${datafile}:cache_hitpass:AVERAGE",
		"DEF:cache_miss=${datafile}:cache_miss:AVERAGE",
		"DEF:client_req=${datafile}:client_req:AVERAGE",

		'AREA:cache_hit#32CD32:Cache hits',
		'STACK:cache_hitpass#4169E1:Cache hit pass',
		'STACK:cache_miss#FF0000:Cache miss',
		'LINE:client_req#000000:Client requests',
	);

    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
