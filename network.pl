#!/usr/bin/perl
#
# RRD script to display network statistics
# 2003-2004,2011 (c) by Christian Garbs <mitch@cgarbs.de>
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
my $datafile_template = "$conf{DBPATH}/DEVICE.rrd";
my $picbase_template  = "$conf{OUTPATH}/DEVICE-";
my @devices  = @{$conf{NETWORK_DEVICES}};

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# get traffic data (only open NETDEV once)
open NETDEV, '<', '/proc/net/dev' or die "can't open /proc/net/dev: $!";
my (undef, undef, @netdev) = <NETDEV>;
close NETDEV or die "can't close /proc/net/dev: $!";
my %device;
foreach ( @netdev ) {
    my ($dev, $data) = split /:/;
    $dev =~ tr/ //d;
    $device{$dev} = [ split /\s+/, ' '.$data ];
}

# iterate over all given devices
foreach ( @devices ) {

    # get current variables
    my ($device, $input_max, $output_max) = @{$_};
    my $datafile = $datafile_template;
    my $picbase  = $picbase_template;

    $datafile =~ s/DEVICE/$device/;
    $picbase  =~ s/DEVICE/$device/;

    # generate database if absent
    if ( ! -e $datafile ) {
	RRDs::create($datafile,
		     "--step=60",
		     "DS:input:COUNTER:600:0:${input_max}",
		     "DS:output:COUNTER:600:0:${output_max}",
		     'RRA:AVERAGE:0.5:1:600',
		     'RRA:AVERAGE:0.5:6:700',
		     'RRA:AVERAGE:0.5:24:775',
		     'RRA:AVERAGE:0.5:288:797',
		     'RRA:MAX:0.5:1:600',
		     'RRA:MAX:0.5:6:700',
		     'RRA:MAX:0.5:24:775',
		     'RRA:MAX:0.5:288:797'
		 );
	  $ERR=RRDs::error;
	  die "ERROR while creating $datafile: $ERR\n" if $ERR;
	  print "created $datafile\n";
      }
    
    # update database
    if ( exists $device{$device} ) {
	RRDs::update($datafile,
		     "N:@{$device{$device}}[1]:@{$device{$device}}[9]"
		     );
      } else {
	RRDs::update($datafile,
		     'N:U:U'
		     );
      }
    $ERR=RRDs::error;
    die "ERROR while updating $datafile: $ERR\n" if $ERR;

    ### skip drawing of tunnels
    next if $device =~ /^tun/;

    # draw pictures
    foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
	my ($time, $scale) = @{$_};
	RRDs::graph($picbase . $scale . ".png",
		    "--start=-${time}",
		    '--lazy',
		    '--imgformat=PNG',
		    "-c","BACK#FF000000",
		    "-c","CANVAS#FFFFFF00",
		    "-c","SHADEA#FF000000",
		    "-c","SHADEB#FF000000",
                    "--border=0",
		    "--title=${hostname} ${device} network traffic (last $scale)",
		    "--width=$conf{GRAPH_WIDTH}",
		    "--height=$conf{GRAPH_HEIGHT}",
		    "--alt-autoscale",

		    "DEF:input=${datafile}:input:AVERAGE",
		    "DEF:outputx=${datafile}:output:AVERAGE",
		    "DEF:input_max=${datafile}:input:MAX",
		    "DEF:output_maxx=${datafile}:output:MAX",

		    'CDEF:output=0,outputx,-',
		    'CDEF:output_max=0,output_maxx,-',

#		    'AREA:input_max#B0F0B0:max input [octets/sec]',
#		    'AREA:output_max#B0B0F0:max output [octets/sec]',
#		    'COMMENT:\n',
#		    'AREA:input#00D000:avg input [octets/sec]',
#		    'AREA:output#0000D0:avg output [octets/sec]',
#		    'COMMENT:\n',

#		"DEF:in=$rrd/$_[0].rrd:in:AVERAGE",
#		"DEF:out=$rrd/$_[0].rrd:out:AVERAGE",
#		"CDEF:out_neg=out,-1,*",
		"AREA:input#32CD32:Incoming",
		"LINE1:input#000000",
		"GPRINT:input_max:MAX:  Max\\: %7.1lf %s",
#		"GPRINT:in:AVERAGE: Avg\\: %5.1lf %S",
		"GPRINT:input:LAST: Current\\: %7.1lf %Sbytes/sec\\n",
		"AREA:output#4169E1:Outgoing",
		"LINE1:output#000000",
		"GPRINT:output_maxx:MAX:  Max\\: %7.1lf %S",
#		"GPRINT:out:AVERAGE: Avg\\: %5.1lf %S",
		"GPRINT:outputx:LAST: Current\\: %7.1lf %Sbytes/sec\\n",
		"HRULE:0#000000",

		    );
	$ERR=RRDs::error;
	die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
    }

}
