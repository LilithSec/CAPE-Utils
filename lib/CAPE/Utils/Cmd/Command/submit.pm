package CAPE::Utils::Cmd::Command::submit;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'submit files/dirs to CAPE';
}

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

sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $args->[0] ) ) {
		$self->usage_error('No files/dirs to submit specified');
	}

	return;
}

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
