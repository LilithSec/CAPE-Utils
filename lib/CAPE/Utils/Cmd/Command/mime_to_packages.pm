package CAPE::Utils::Cmd::Command::mime_to_packages;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

# The one line summary App::Cmd shows beside this sub command in the listing
# printed by "cape_utils commands" and by the top level usage output.
#
# Args:
#     - none
#
# Returns the summary as a string, with no trailing newline.
#
#     print CAPE::Utils::Cmd::Command::mime_to_packages->abstract . "\n";
sub abstract {
	return 'show the mime type to package settings';
}

# The usage block App::Cmd prints for "cape_utils help mime_to_packages" and on a
# usage error. The first line is the synopsis and the rest is the longer
# description, which draws out that the table shows resolved values while the INI
# shows raw ones, as the two do not always agree.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::mime_to_packages->usage_desc;
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

# The switches this sub command takes, those being the two alternative output
# forms and --diff, plus the shared JSON and config switches.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::mime_to_packages->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return (
		[ 'as_ini|as-ini', 'output as INI, suitable for pasting into the config' ],
		[ 'diff',          'only output what differs from the shipped defaults' ],
		$class->json_opts, $class->ini_opt,
	);
}

# Checks that only one output form was asked for before execute is reached.
#
# --json and --as-ini are both whole output formats, so asking for both is asking
# for two different things on the one STDOUT. --diff is not checked as it applies
# to all three forms.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'json' and 'as_ini' are
#       the two being checked against each other. Required, and supplied by
#       App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing when the arguments are usable. Calls usage_error, which prints
# the usage and exits non zero, when both forms were asked for.
#
#     $ cape_utils mime_to_packages --json --as-ini
#     --json and --as-ini may not be used together
sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( $opt->{json} && $opt->{as_ini} ) {
		$self->usage_error('--json and --as-ini may not be used together');
	}

	return;
}

# Runs the sub command, printing the mime type to package settings in one of the
# three forms, the table being the default.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'as_ini' is 0/1 for the
#       INI form, 'diff' is 0/1 for limiting the output to what differs from the
#       shipped defaults, 'json' and 'pretty' control the JSON output, and 'ini'
#       is the config file to use. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing, the point of it being what it prints. Dies if the config can
# not be read.
#
#     $ cape_utils mime_to_packages
#     $ cape_utils mime_to_packages --as-ini --diff
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
