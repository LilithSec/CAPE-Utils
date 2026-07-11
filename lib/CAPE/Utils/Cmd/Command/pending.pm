package CAPE::Utils::Cmd::Command::pending;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'show pending tasks';
}

sub usage_desc {
	return '%c pending [-i <config>] [-C] [-w <where>] [--json] [--pretty]

Print info on penidng tasks. Unless -C or --json is given, it will
print out a table.
';
}

sub opt_spec {
	my ($class) = @_;
	return (
		[ 'count|C',   'print the pending count instead of the table' ],
		[ 'where|w=s', 'additional SQL args for use when getting pending items' ],
		$class->json_opts, $class->ini_opt,
	);
}

sub execute {
	my ( $self, $opt, $args ) = @_;

	my $cape_utils = $self->cape_utils($opt);

	if ( $opt->{count} ) {
		print $cape_utils->get_pending_count( where => $opt->{where} ) . "\n";
	} elsif ( $opt->{json} ) {
		$self->print_json( $opt, $cape_utils->get_pending( where => $opt->{where} ) );
	} else {
		print $cape_utils->get_pending_table( where => $opt->{where} );
	}

	return;
} ## end sub execute

1;
