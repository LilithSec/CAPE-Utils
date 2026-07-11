package CAPE::Utils::Cmd::Command::eve;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'invoke CAPE::Utils->eve_process';
}

sub usage_desc {
	return '%c eve

Calls CAPE::Utils->eve_process to update the EVE file.
';
}

sub opt_spec {
	my ($class) = @_;
	return ( $class->ini_opt, );
}

sub execute {
	my ( $self, $opt, $args ) = @_;

	$self->cape_utils($opt)->eve_process();

	return;
}

1;
