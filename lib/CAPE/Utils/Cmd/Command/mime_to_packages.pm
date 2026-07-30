package CAPE::Utils::Cmd::Command::mime_to_packages;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'show the mime type to package settings';
}

sub usage_desc {
	return '%c mime_to_packages [-i <config>] [--as-ini] [--diff] [--json] [--pretty]

Print the mime type to package settings used by submit --mime-package.

By default a table is printed. The package column of it is what would
actually be used, so a mime type mapped to auto shows as auto and a mime
type mapped to a empty value shows as the mime_to_package_default.

--as-ini prints it as INI instead, suitable for pasting into the config.
Unlike the table, the values are the raw config values.

--diff limits any of the three to what differs from the shipped defaults,
making --as-ini --diff a minimal config fragment.
';
} ## end sub usage_desc

sub opt_spec {
	my ($class) = @_;
	return (
		[ 'as_ini|as-ini', 'output as INI, suitable for pasting into the config' ],
		[ 'diff',          'only output what differs from the shipped defaults' ],
		$class->json_opts, $class->ini_opt,
	);
}

sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( $opt->{json} && $opt->{as_ini} ) {
		$self->usage_error('--json and --as-ini may not be used together');
	}

	return;
}

sub execute {
	my ( $self, $opt, $args ) = @_;

	my $cape_utils = $self->cape_utils($opt);

	if ( $opt->{json} ) {
		$self->print_json( $opt, $cape_utils->mime_packages( diff => $opt->{diff} ) );
	} elsif ( $opt->{as_ini} ) {
		print $cape_utils->mime_packages_ini( diff => $opt->{diff} );
	} else {
		print $cape_utils->mime_packages_table( diff => $opt->{diff} );
	}

	return;
} ## end sub execute

1;
