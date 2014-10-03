#!/usr/bin/perl

my $SD = "./gpx";
my $ED = "./endomondo";

mkdir $SD;
mkdir $ED;

while (<$SD/*gpx>)
{
	my $sf = $_;
	my $ef = $sf;
	$ef =~ s{$SD}{$ED};

	if (-s $sf < 100 || (-f $ef && -s $sf == -s $ef))
	{
#		print "skipping: $sf\n";
		next;
	}

	print "transferring: $sf -> $ef\n";

	my $call = "perl endomondo-upload.pl -g $sf";
	print "call($call)\n";

	my $endoret = system($call);

	if ($endoret == 0)
	{
		print "ok: $sf\n";
		print `cp "$sf" "$ef"`;
	}
	else
	{
		print "FAIL: $sf\n";
	}

	print "sleeping...\n";
	sleep(int(rand(90)+30));
}
