package CAPE::Utils::Cmd::Command::poetry;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'run an arbitrary poetry command in the CAPE base dir as the cape user';
}

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

sub opt_spec {
	my ($class) = @_;
	return (
		[ 'quiet',   'do not print the output from the command' ],
		[ 'verbose', 'print to STDERR what it is doing' ],
		$class->json_opts, $class->ini_opt,
	);
}

sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $args->[0] ) ) {
		$self->usage_error('No poetry arguments specified');
	}

	return;
}

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
