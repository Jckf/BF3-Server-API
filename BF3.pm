#!/dev/null

## BattleField 3 remote server admin API by Jim C K Flaten (jckf@jckf.no)

package BF3;

use strict;
use warnings;
use Time::HiRes 'sleep';
use IO::Select;
use IO::Socket::INET;

sub new {
	my ($class,%args) = @_;

	my $self = {
		'sequence'  => 0,
		'callbacks' => [ sub { exit } ]
	};

	$self->{$_} = $args{$_} for keys %args;

	$self->{'socket'} = IO::Socket::INET->new($self->{'server'} . ':' . $self->{'port'}) or die($!);
	$self->{'select'} = IO::Select->new($self->{'socket'});

	bless($self,$class);
}

sub run {
	my ($self) = @_;

	while ($self->{'socket'}) {
		if ($self->{'select'}->can_read(0)) {
			my ($sequence,@data) = $self->read();
			if (defined $sequence) {
				$self->{'sequence'} = $sequence if $sequence > $self->{'sequence'};

				if (defined $self->{'callbacks'}->[$sequence]) {
					&{$self->{'callbacks'}->[$sequence]}($sequence,@data);
				} elsif (defined $self->{'callbacks'}->[0]) {
					&{$self->{'callbacks'}->[0]}($sequence,@data);
				}
			} else {
				$self->{'socket'}->close();
				undef $self->{'socket'};
			}
		} else {
			sleep 0.01;
		}
	}
}

sub query {
	my $callback = ref $_[@_ - 1] eq 'CODE' ? pop : 0;
	my ($self,@words) = @_;
	my $sequence = $self->write(@words);
	$self->set_callback($sequence,$callback) if $callback;
}

sub set_callback {
	$_[0]->{'callbacks'}->[$_[1]] = $_[2];
}

sub write {
	my ($self,@words) = @_;

	$self->{'sequence'}++;

	my $sequence = chr($self->{'sequence'});
	vec($sequence,31,1) = 1;
	vec($sequence,30,1) = 0;
	vec($sequence,29,1) = 0;

	my $data = ''; $data .= $self->build($_) for @words;

	syswrite($self->{'socket'},
		$sequence .
		pack('l',4 + 4 + 4 + length($data)) .
		pack('l',scalar(@words)) .
		$data
	);

	return $self->{'sequence'};
}

sub build {
	my ($self,$word) = @_;

	return(
		pack('l',length($word)) .
		$word .
		"\0"
	);
}

sub read {
	my ($self) = @_;

	my $sequence;
	sysread($self->{'socket'},$sequence,4) or return;
	vec($sequence,31,1) = 0;
	vec($sequence,30,1) = 0;
	vec($sequence,29,1) = 0;
	$sequence = ord($sequence);

	my $size;
	sysread($self->{'socket'},$size,4) or return;
	$size = unpack('l',$size);

	my $words;
	sysread($self->{'socket'},$words,4) or return;
	$words = unpack('l',$words);

	my @data;
	for (1 .. $words) {
		push(@data,$self->parse());
	}

	return($sequence,@data);
}

sub parse {
	my ($self) = @_;

	my $size;
	sysread($self->{'socket'},$size,4);
	$size = unpack('l',$size);

	my $data;
	sysread($self->{'socket'},$data,$size);

	my $null;
	sysread($self->{'socket'},$null,1);

	return $data;
}

1;
