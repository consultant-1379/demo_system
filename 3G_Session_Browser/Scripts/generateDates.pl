#!/usr/bin/perl -w
use strict;
use warnings;
use POSIX; # for strftime
my $time = time ();#Time now since EPOC (in seconds)
my $secondsInADay = 24*60*60;
my @time = gmtime ();#Not used!!!
my $offset;



if (@ARGV != 2 ) {
	print "
	Please enter the number of days (from today) that you want dates as the first argument. \n 
	The second argument is the offset in days i.e. for today date it's '0' to start from tomorrow dates it's 1 etc.
	\n
	Example:
	perl generateDates.pl 2 -1
	Generate two days date starting from yesterday
	 \n\n";
	exit;
}

$offset=$ARGV[1]*$secondsInADay;
$time+=$offset;


#$time = $time - $time[6] * $seconds;
for my $wday (0..$ARGV[0]-1) {
    my @wday = gmtime ($time);
    print strftime ("%Y-%m-%d  \n", @wday);
	$time += $secondsInADay;
}


#2013-05-06
########################################################################




