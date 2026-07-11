package CAPE::Utils::Cmd::Command::munge;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'munge a report JSON';
}

sub usage_desc {
	return '%c munge -r $report_json

Munges the specified report JSON.

For more information, see Report Munge Section
in the docs for CAPE::Utils.
';
}

sub opt_spec {
	my ($class) = @_;
	return ( [ 'report|r=s', 'the report JSON to munge' ], $class->ini_opt, );
}

sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $opt->{report} ) ) {
		$self->usage_error('No report JSON specified via -r');
	}

	return;
}

sub execute {
	my ( $self, $opt, $args ) = @_;

	$self->cape_utils($opt)->munge( file => $opt->{report} );

	return;
}

1;
