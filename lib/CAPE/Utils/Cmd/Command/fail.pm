package CAPE::Utils::Cmd::Command::fail;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'fail pending tasks';
}

sub usage_desc {
	return '%c fail -w "id = 404"

Uses the specified where statement to fail pending items.

Unless fail_all is set to 1 in the config, where must be given.
';
}

sub opt_spec {
	my ($class) = @_;
	return ( [ 'where|w=s', 'additional SQL args for use when failing pending items' ], $class->ini_opt, );
}

sub execute {
	my ( $self, $opt, $args ) = @_;

	print $self->cape_utils($opt)->fail( where => $opt->{where} );

	return;
}

1;
