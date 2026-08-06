package CAPE::Utils::Cmd::Command::poetry;

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
#     print CAPE::Utils::Cmd::Command::poetry->abstract . "\n";
sub abstract {
	return 'run an arbitrary poetry command in the CAPE base dir as the cape user';
}

# The usage block App::Cmd prints for "cape_utils help poetry" and on a usage
# error. The first line is the synopsis and the rest is the longer description,
# which draws the distinction with "exec" as the two are easily confused.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::poetry->usage_desc;
sub usage_desc {
	return 'cape_utils poetry [-i <config>] [--quiet] [--verbose] [--json] [--pretty] -- <arg>...

Run an arbitrary poetry command from the CAPE base directory as the configured
cape_runas user. Unlike "exec", which wraps the command in "poetry run", the
arguments are handed straight to poetry, so anything poetry accepts may be run.

Poetry must be enabled in the config; if it is disabled (poetry=0) this dies.

Use "--" to separate cape_utils options from poetry and its arguments so that
flags meant for poetry are not parsed by cape_utils, e.g.

    cape_utils poetry -- install
    cape_utils poetry -- add requests
    cape_utils poetry -- run python3 utils/process.py -r 1
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
#     my @spec = CAPE::Utils::Cmd::Command::poetry->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return (
		[ 'quiet',   'do not print the output from the command' ],
		[ 'verbose', 'print to STDERR what it is doing' ],
		$class->json_opts, $class->ini_opt,
	);
}

# Checks the sub command was given something to hand to poetry before execute is
# reached, as poetry with no arguments just prints its own usage.
#
# Args:
#     - opt :: The options hash ref built from opt_spec, unused here. Required,
#       and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments, that being the
#       arguments for poetry. Required, and supplied by App::Cmd.
#
# Returns nothing when the arguments are usable. Calls usage_error, which prints
# the usage and exits non zero, when nothing was given.
#
#     $ cape_utils poetry
#     No poetry arguments specified
sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $args->[0] ) ) {
		$self->usage_error('No poetry arguments specified');
	}

	return;
}

# Runs the sub command, handing the arguments off to CAPE::Utils->poetry, which
# runs poetry from the CAPE base directory as the configured cape_runas user.
#
# --json implies --quiet, as the command output is already in the JSON and
# printing it as well would leave the JSON on STDOUT mixed in with it.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'quiet' and 'verbose'
#       are 0/1, 'json' and 'pretty' control the JSON output, and 'ini' is the
#       config file to use. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the arguments for poetry, such as
#       [ 'run', 'python3', 'utils/process.py', '-r', '1' ]. Required, and
#       supplied by App::Cmd.
#
# Returns nothing, but exits 1 if poetry failed, so the exit status is usable
# from a shell. Dies if the config can not be read, poetry is disabled in the
# config, or the CAPE base directory can not be entered.
#
#     $ cape_utils poetry --json --pretty -- install
sub execute {
	my ( $self, $opt, $args ) = @_;

	my $quiet = $opt->{quiet};
	if ( $opt->{json} ) {
		$quiet = 1;
	}

	my $results = $self->cape_utils($opt)->poetry(
		args    => $args,
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
