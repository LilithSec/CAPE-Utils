package CAPE::Utils::Cmd::Command::exec;

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
#     print CAPE::Utils::Cmd::Command::exec->abstract . "\n";
sub abstract {
	return 'exec a command in the CAPE base dir via poetry';
}

# The usage block App::Cmd prints for "cape_utils help exec" and on a usage
# error. The first line is the synopsis and the rest is the longer description,
# which spells out the "--" separator as flags meant for the command being ran
# would otherwise be eaten by cape_utils.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::exec->usage_desc;
sub usage_desc {
	return 'cape_utils exec [-i <config>] [--quiet] [--verbose] [--json] [--pretty] -- <command> [<arg>...]

Run an arbitrary command from the CAPE base directory, wrapped in "poetry run"
(when poetry is enabled in the config), the same way submissions are executed.

Use "--" to separate cape_utils options from the command and its arguments so
that flags meant for the command are not parsed by cape_utils, e.g.

    cape_utils exec -- python3 utils/process.py -r 1
';
} ## end sub usage_desc

# The switches this sub command takes, those being --quiet and --verbose for
# controlling what gets printed, plus the shared JSON and config switches.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::exec->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return (
		[ 'quiet',   'do not print the output from the command' ],
		[ 'verbose', 'print to STDERR what it is doing' ],
		$class->json_opts, $class->ini_opt,
	);
}

# Checks the sub command was given something to run before execute is reached.
#
# Args:
#     - opt :: The options hash ref built from opt_spec, unused here. Required,
#       and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments, that being the
#       command and its arguments. Required, and supplied by App::Cmd.
#
# Returns nothing when the arguments are usable. Calls usage_error, which prints
# the usage and exits non zero, when no command was given.
#
#     $ cape_utils exec
#     No command to exec specified
sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $args->[0] ) ) {
		$self->usage_error('No command to exec specified');
	}

	return;
}

# Runs the sub command, handing the command off to CAPE::Utils->exec, which runs
# it from the CAPE base directory as the configured cape_runas user.
#
# --json implies --quiet, as the command output is already in the JSON and
# printing it as well would leave the JSON on STDOUT mixed in with it.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'quiet' and 'verbose'
#       are 0/1, 'json' and 'pretty' control the JSON output, and 'ini' is the
#       config file to use. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the command to run and its arguments, such as
#       [ 'python3', 'utils/process.py', '-r', '1' ]. Required, and supplied by
#       App::Cmd.
#
# Returns nothing, but exits 1 if the command it ran failed, so the exit status
# is usable from a shell. Dies if the config can not be read or the CAPE base
# directory can not be entered.
#
#     $ cape_utils exec --json --pretty -- python3 utils/process.py -r 1
sub execute {
	my ( $self, $opt, $args ) = @_;

	my $quiet = $opt->{quiet};
	if ( $opt->{json} ) {
		$quiet = 1;
	}

	my $results = $self->cape_utils($opt)->exec(
		command => $args,
		quiet   => $quiet,
		verbose => $opt->{verbose},
	);

	if ( $opt->{json} ) {
		$self->print_json( $opt, $results );
	}

	if ( !$results->{success} ) {
		exit 1;
	}

	return;
} ## end sub execute

1;
