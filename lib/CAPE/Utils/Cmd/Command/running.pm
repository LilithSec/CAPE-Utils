package CAPE::Utils::Cmd::Command::running;

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
#     print CAPE::Utils::Cmd::Command::running->abstract . "\n";
sub abstract {
	return 'show running tasks';
}

# The usage block App::Cmd prints for "cape_utils help running" and on a usage
# error. The first line is the synopsis and the rest is the longer description.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::running->usage_desc;
sub usage_desc {
	return 'cape_utils running [-i <config>] [-C] [-w <where>] [--json] [--pretty]

Show running CAPE tasks. Will print a table unless -C or --json is given.
';
}

# The switches this sub command takes, those being -C/--count for the count
# instead of the listing and -w/--where for narrowing it down, plus the shared
# JSON and config switches.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::running->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return (
		[ 'count|C',   'print the running count instead of the table' ],
		[ 'where|w=s', 'additional SQL args for use when getting running items' ],
		$class->json_opts, $class->ini_opt,
	);
}

# Runs the sub command, printing the running tasks in one of three forms.
#
# -C wins over --json, as asking for the count is asking for a single number, and
# with neither the table is printed.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'count' is 0/1 for
#       printing the count instead, 'where' is a SQL fragment such as
#       'machine = "win10"', 'json' and 'pretty' control the JSON output, and
#       'ini' is the config file to use. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing, the point of it being what it prints. Dies if the config can
# not be read or the database call fails.
#
#     $ cape_utils running -C
#     $ cape_utils running -w 'machine = "win10"' --json --pretty
sub execute {
	my ( $self, $opt, $args ) = @_;

	my $cape_utils = $self->cape_utils($opt);

	if ( $opt->{count} ) {
		print $cape_utils->get_running_count( where => $opt->{where} ) . "\n";
	} elsif ( $opt->{json} ) {
		$self->print_json( $opt, $cape_utils->get_running( where => $opt->{where} ) );
	} else {
		print $cape_utils->get_running_table( where => $opt->{where} );
	}

	return;
} ## end sub execute

1;
