package CAPE::Utils::Cmd::Command::exec;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'exec a command in the CAPE base dir via poetry';
}

sub usage_desc {
	return 'cape_utils exec [-i <config>] [--quiet] [--verbose] [--json] [--pretty] -- <command> [<arg>...]

Run an arbitrary command from the CAPE base directory, wrapped in "poetry run"
(when poetry is enabled in the config), the same way submissions are executed.

Use "--" to separate cape_utils options from the command and its arguments so
that flags meant for the command are not parsed by cape_utils, e.g.

    cape_utils exec -- python3 utils/process.py -r 1
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
		$self->usage_error('No command to exec specified');
	}

	return;
}

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
