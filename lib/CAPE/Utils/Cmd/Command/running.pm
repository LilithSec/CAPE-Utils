package CAPE::Utils::Cmd::Command::running;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'show running tasks';
}

sub usage_desc {
	return 'cape_utils running [-i <config>] [-C] [-w <where>] [--json] [--pretty]

Show running CAPE tasks. Will print a table unless -C or --json is given.
';
}

sub opt_spec {
	my ($class) = @_;
	return (
		[ 'count|C',   'print the running count instead of the table' ],
		[ 'where|w=s', 'additional SQL args for use when getting running items' ],
		$class->json_opts, $class->ini_opt,
	);
}

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
