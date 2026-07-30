package CAPE::Utils::Cmd::Command::mime_to_packages;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'show the mime type to package settings';
}

sub usage_desc {
	return '%c mime_to_packages [-i <config>] [--json] [--pretty]

Print the mime type to package settings used by submit --mime-package.

Unless --json is given, a table is printed. The package column of it is
what would actually be used, so a mime type mapped to auto shows as auto
and a mime type mapped to a empty value shows as the
mime_to_package_default.
';
}

sub opt_spec {
	my ($class) = @_;
	return ( $class->json_opts, $class->ini_opt, );
}

sub execute {
	my ( $self, $opt, $args ) = @_;

	my $cape_utils = $self->cape_utils($opt);

	if ( $opt->{json} ) {
		$self->print_json( $opt, $cape_utils->mime_packages );
	} else {
		print $cape_utils->mime_packages_table;
	}

	return;
} ## end sub execute

1;
