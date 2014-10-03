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
use IO::Socket::SSL qw();

BEGIN { 
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0 ;
# $ENV{HTTPS_DEBUG} = 1;
}



my $E = 'https://www.endomondo.com';

my $rev = '$Rev: 2623 $';
$rev =~ s/.*?(\d+).*/v$1/; 

# command line
my $opt_gpx = undef;
my $opt_help = 0;

GetOptions(
        "gpx|g=s"            => \$opt_gpx,
        # "directory|d=s"         => \$opt_dir,
        # "user|u=s"              => \$opt_user,
        # "suid|s"                => \$opt_suid,
        # "email|e=s"             => \$opt_email,
        # "from|f=s"              => \$opt_from,
        # "passlen|p=i"           => \$opt_plen,
        # "urlprefix|x=s"         => \$opt_url,
        "help|h"                => \$opt_help,
) or usage();


sub usage
{
        print STDERR <<EOF;
Usage:
    $0 options

Options:
	--gpx or -g filename.gpx 
	# --first or -f (ony first page)
    # --directory or -d directory_name (absolute, reuired)
    # --user or -u username    
    # --suid or -s (set-uid for specified user - otherwise just chown created files)
    # --email or -e email\@domain.tld (email to get passwords)
    # --from or -f email\@fomain.tld (source email)
    # --passlen or -p n (password length, default = 8)
    # --urlprefix or -x URL (url prefix)
EOF
    exit 1;
}

# usage() unless defined $opt_cfg && -f $opt_cfg;
die "cannot find file ($opt_gpx): $!" unless -f $opt_gpx;

sub LOG
{
    my $d = POSIX::strftime("%F %T", localtime);
    print STDERR "$d ",join(" ",@_),"\n";
}

binmode STDOUT, ":utf8";

LOG "endomondo-upload version $rev";

LOG "reading configs";
my $cfg = Config::INI::Reader->read_file("$Bin/endomondo-upload.ini");


LOG "authenticating";

my $mech = WWW::Mechanize->new();
$mech->agent_alias("Linux Mozilla");

# $mech->ssl_opts( SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE, SSL_hostname => '', verify_hostname => 0 );
$mech->ssl_opts( SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE);

# $mech->proxy('http', 'http://127.0.0.1:8080');

$mech->get("$E/login");

# print $mech->content();
# exit(0);

$mech->submit_form(
    fields => {
        email => $cfg->{endomondo}->{user},
        password => $cfg->{endomondo}->{password},
    }
);


$mech->get("$E/workouts/create");

my $c = $mech->content();
die ("p1: $c") unless $c =~ /(\?wicket:interface=:\d+:pageContainer:lowerSection:lowerMain:lowerMainContent:importFileLink[^']+)/;
my $u = "$E$1";

die ("p1b: $c") unless $c =~ /(\?wicket:interface=:\d+:pageContainer:headerRightContent:signOutLink[^'"]+)/;
my $logoutlink = "$E$1";


LOG "upload menu $u";
$mech->get($u);
$c = $mech->content();

die ("p2: $c") unless $c =~ /src="(\?wicket:interface=:\d+:pageContainer:lightboxContainer:lightboxContent:iframePage:\d*:ILinkListener[^"]+)/;
$u = "$E$1";

LOG "upload form $u";
$mech->get($u);
$c = $mech->content();

die ("p3: $c") unless $c =~ /(\?wicket:interface=:\d+:importPanel:wizardStepPanel:uploadForm:uploadSumbit[^']+)/;
$u = "$E$1";
$u =~ s/&amp;/&/g; # do we need it?

LOG "uploading to $u";
$mech->field("uploadFile", $opt_gpx);
$mech->form_number(0)->action($u);
$c = $mech->submit()->decoded_content();

die ("p4: $c") unless $c =~ /(\?wicket:interface=:\d+:importPanel:wizardStepPanel:reviewForm:reviewSumbit[^']+)/;
$u = "$E$1";
$u =~ s/&amp;/&/g; # do we need it?
LOG "confirmation to $u";

$mech->field("workoutRow:0:mark","on");
$mech->field("workoutRow:0:sport","3");
$mech->form_number(0)->action($u);
$c = $mech->submit()->decoded_content();

die ("p5: $c") unless $c =~ /onIFrameWizardExit/;

LOG "uploaded successfully";

# LOG "logout $logoutlink";
# $mech->get($logoutlink);
# $c = $mech->content();

# print $c;
