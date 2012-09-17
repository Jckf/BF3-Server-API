#!/usr/bin/perl
use strict;
use warnings;
use lib '.';
use BF3;

print 'Connecting...' . "\n";

my $api = BF3->new(
	'server'   => '81.166.125.5',
	'port'     => 21055
);

$api->set_callback(0,sub {
	my (@data) = @_;

	print "\n" . 'Sequence ' . $data[0] . "\n";
	print '=' x 79 . "\n";

	for (1 .. @data - 1) {
		print $_ . ' = ' . $data[$_] . "\n";
	}
});

$api->query(
	'login.plainText',
	'jim',

	sub {
		if ($_[1] ne 'OK') {
			print 'Login failed.' . "\n";
			undef $api->{'socket'};
		} else {
			print 'Login OK.' . "\n";

			$api->query(
				'admin.eventsEnabled',
				'true'
			);
		}
	}
);

$api->run();

print 'Disconnected.' . "\n";
