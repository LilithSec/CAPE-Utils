package CAPE::Utils::Cmd::Command::munge;

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
#     print CAPE::Utils::Cmd::Command::munge->abstract . "\n";
sub abstract {
	return 'munge a report JSON';
}

# The usage block App::Cmd prints for "cape_utils help munge" and on a usage
# error. The first line is the synopsis, in which %c is replaced with the name
# the script was invoked as, and the rest is the longer description.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::munge->usage_desc;
sub usage_desc {
	return '%c munge -r $report_json

Munges the specified report JSON.

For more information, see Report Munge Section
in the docs for CAPE::Utils.
';
}

# The switches this sub command takes, those being -r/--report for the report to
# work on and the shared -i/--ini.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::munge->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return ( [ 'report|r=s', 'the report JSON to munge' ], $class->ini_opt, );
}

# Checks a report to munge was given before execute is reached.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. Only 'report' is looked
#       at, that being the path to the report JSON. Required, and supplied by
#       App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing when the arguments are usable. Calls usage_error, which prints
# the usage and exits non zero, when -r was not given.
#
#     $ cape_utils munge
#     No report JSON specified via -r
sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $opt->{report} ) ) {
		$self->usage_error('No report JSON specified via -r');
	}

	return;
}

# Runs the sub command, munging the report via CAPE::Utils->munge, which rewrites
# the report in place per the report_munge section of the config.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'report' is the path to
#       the report JSON and 'ini' is the config file to use. Required, and
#       supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing. Dies if the config can not be read, or if the report is
# missing or not parsable as JSON.
#
#     $ cape_utils munge -r /opt/CAPEv2/storage/analyses/1/reports/report.json
sub execute {
	my ( $self, $opt, $args ) = @_;

	$self->cape_utils($opt)->munge( file => $opt->{report} );

	return;
}

1;
