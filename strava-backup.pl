#!/usr/bin/perl

use warnings;
use strict;
use utf8;

use Data::Dumper;
use Time::HiRes;
use File::Slurp;
use Config::INI;
use Config::INI::Reader;
use Config::INI::Writer;
use FindBin qw($Bin);
use POSIX qw(strftime);
# use LWP::Simple;
# use Getopt::Std;
use Getopt::Long;

use WWW::Mechanize;
use JSON;

my $rev = '$Rev: 2623 $';
$rev =~ s/.*?(\d+).*/v$1/; 

# command line
my $opt_first = undef;

GetOptions(
        "first|f"            => \$opt_first,
        # "help|h"                => \$opt_help,
) or usage();


sub usage
{
        print STDERR <<EOF;
Usage:
    $0 options

Options:
	--first or -f (ony first page)
EOF
    exit 1;
}

# usage() unless defined $opt_cfg && -f $opt_cfg;


sub LOG
{
    my $d = POSIX::strftime("%F %T", localtime);
    print STDERR "$d ",join(" ",@_),"\n";
}

binmode STDOUT, ":utf8";

LOG "strava-backup version $rev";

LOG "reading configs";
my $cfg = Config::INI::Reader->read_file("$Bin/strava-backup.ini") or die 'cannot open config file';



my $mech = WWW::Mechanize->new();
$mech->agent_alias("Linux Mozilla");

$mech->get("https://app.strava.com/login");

$mech->submit_form(
    fields      => {
        email    => $cfg->{strava}->{user},
        password    => $cfg->{strava}->{password},
    }
);

$mech->get("http://app.strava.com/athlete/training");
my $page = $mech->content();
my $csrf = '';
if ($page =~ /meta\s+content="([^"]+)"\s+name="csrf-token"/)
{
	$csrf = $1;
	$mech->add_header("X-CSRF-Token" => $csrf);
}


$mech->add_header("X-Requested-With" => "XMLHttpRequest");
$mech->add_header("Accept","text/javascript, application/javascript, application/ecmascript, application/x-ecmascript");


my $pager = 1;
my $total = 0;
my $i = 1;
my $workouts;
while (1)
{

	LOG "getting workouts, page $pager";

	#$mech->get("http://app.strava.com/athlete/training_activities?new_activity_only=false");
	$mech->get("http://app.strava.com/athlete/training_activities?new_activity_only=false&page=$pager&per_page=20");
	$page = $mech->content();
	#print "\n\n---\n\n";
	my $json = decode_json $page;

	for my $ride (@{$json->{models}})
	{

		# type: Ride, Workout, Hike, Walk, Swim

# ./fix-filenames-utf8.sh:find . -exec rename-iconv.pl utf8 'ascii//TRANSLIT' "{}" \; 

		print "$i $ride->{id} $ride->{type} $ride->{name}\n";
		$workouts->{$ride->{id}} = $ride->{type} if $ride->{type} =~ m/(Ride|Hike|Walk|Swim)/;

		$i++;
	}
	# print Dumper $json;

	$total = $json->{total};
	last if $pager*20 > $total;

	last if $opt_first;
	$pager++;
}

for my $w (sort { $a <=> $b } keys %$workouts)
{
	my $fn = "gpx/$w.gpx";
	next if -f $fn;

	LOG "downloading workout ($w)";

	$mech->get("http://app.strava.com/activities/$w/export_gpx");
	$mech->save_content($fn);

}

