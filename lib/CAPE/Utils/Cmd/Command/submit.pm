package CAPE::Utils::Cmd::Command::submit;

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
#     print CAPE::Utils::Cmd::Command::submit->abstract . "\n";
sub abstract {
	return 'submit files/dirs to CAPE';
}

# The usage block App::Cmd prints for "cape_utils help submit" and on a usage
# error. The first line is the synopsis and the rest is the longer description,
# which covers how --mime-package and --package interact as that is the part
# people get wrong.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::submit->usage_desc;
sub usage_desc {
	return 'cape_utils submit [-i <config>] [--clock <time>] [--timeout <seconds>]
   [--machine <machine>] [--package> <package] [--options <options>]
   [--tags <tags>] [--enforce_timeout] [--unique] [--json] [--pretty]
   [--quiet] [--mime-package|--no-mime-package] [--dry-run]
   <file/dir> [<file/dir>...]

Submit files or directories to CAPE.

--mime-package works the package out per item from its mime type, using the
mime_packages section of the config. --package always wins over it, with a
package of auto meaning submit with no package and let CAPE decide.

--dry-run prints the item, its mime type, and the package it would be
submitted with, submitting nothing. It may be ran as any user.
';
} ## end sub usage_desc

# The switches this sub command takes, which is most of what CAPE's submit.py
# accepts plus the ones controlling mime type based package selection.
#
# --mime-package is negatable, giving --no-mime-package, so it can be turned off
# per run when mime_to_package is enabled in the config. It is left undef when
# neither form is given so that submit() can tell "not asked for" from "asked to
# be off" and fall back to the config setting.
#
# --random defaults to 1 rather than being left undef, as the shuffling is meant
# to happen unless it was actively turned off.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description, and in the case
# of --random a trailing hash ref holding its default.
#
#     my @spec = CAPE::Utils::Cmd::Command::submit->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return (
		[ 'clock=s',   'timestamp to set the VM clock to, format mm-dd-yyy HH:MM:ss' ],
		[ 'timeout=i', 'timeout value in seconds, default 200' ],
		[ 'machine=s', 'the machine to use, first available if undefined' ],
		[ 'package=s', 'package to use, if not letting CAPE decide, or auto to let CAPE decide' ],
		[
			'mime_package|mime-package!',
			'work the package out per item from its mime type, overriding the mime_to_package config setting'
		],
		[ 'dry_run|dry-run',    'print the mime type and package worked out for each item, submitting nothing' ],
		[ 'options=s',          'option string to be passed via --options' ],
		[ 'random=i',           'randomize the order of submission, default 1', { default => 1 } ],
		[ 'tags=s',             'tags to be passed via --tags' ],
		[ 'platform=s',         'what to pass to --platform' ],
		[ 'enforce_timeout|et', 'force it to run the entire period' ],
		[ 'unique',             'only submit unique items' ],
		[ 'quiet',              'do not print the output from the submission command' ],
		$class->json_opts,
		$class->ini_opt,
	);
} ## end sub opt_spec

# Checks the sub command was given something to submit before execute is reached.
#
# Args:
#     - opt :: The options hash ref built from opt_spec, unused here. Required,
#       and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments, those being
#       the files and directories to submit. Required, and supplied by App::Cmd.
#
# Returns nothing when the arguments are usable. Calls usage_error, which prints
# the usage and exits non zero, when nothing was given to submit.
#
#     $ cape_utils submit
#     No files/dirs to submit specified
sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $args->[0] ) ) {
		$self->usage_error('No files/dirs to submit specified');
	}

	return;
}

# Runs the sub command, handing the items and switches off to
# CAPE::Utils->submit.
#
# --json implies --quiet, as the submission output is already in the JSON and
# printing it as well would leave the JSON on STDOUT mixed in with it.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. The submission
#       switches are passed through to submit() as is, 'json' and 'pretty'
#       control the JSON output, and 'ini' is the config file to use. Required,
#       and supplied by App::Cmd.
#
#     - args :: An array ref of the files and directories to submit, such as
#       [ '/tmp/sample.bin', '/tmp/samples/' ]. Directories are walked by
#       submit(). Required, and supplied by App::Cmd.
#
# Returns nothing, the point of it being what it prints. Dies if the config can
# not be read, or if it is not being ran as the configured cape_runas user and
# enable_sudo is not set, the exception being --dry-run, which submits nothing
# and so may be ran as anyone.
#
#     $ cape_utils submit --dry-run /tmp/samples/
#     $ cape_utils submit --mime-package --json --pretty /tmp/sample.bin
sub execute {
	my ( $self, $opt, $args ) = @_;

	my $quiet = $opt->{quiet};
	if ( $opt->{json} ) {
		$quiet = 1;
	}

	my $results = $self->cape_utils($opt)->submit(
		items           => $args,
		clock           => $opt->{clock},
		timeout         => $opt->{timeout},
		machine         => $opt->{machine},
		package         => $opt->{package},
		mime_to_package => $opt->{mime_package},
		dry_run         => $opt->{dry_run},
		options         => $opt->{options},
		random          => $opt->{random},
		tags            => $opt->{tags},
		platform        => $opt->{platform},
		enforce_timeout => $opt->{enforce_timeout},
		unique          => $opt->{unique},
		quiet           => $quiet,
	);

	if ( $opt->{json} ) {
		$self->print_json( $opt, $results );
	}

	return;
} ## end sub execute

1;
