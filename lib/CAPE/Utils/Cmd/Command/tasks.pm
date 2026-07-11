package CAPE::Utils::Cmd::Command::tasks;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'show tasks';
}

sub usage_desc {
	return 'cape_utils tasks [-i <config>] [-C] [-w <where>] [--direction> <dir>]
    [--order <column>] [--limit <limit>] [--json] [--pretty]


Show CAPE tasks.
';
}

sub opt_spec {
	my ($class) = @_;
	return (
		[ 'count|C',     'print the task count instead of the table' ],
		[ 'where|w=s',   'additional SQL args for use when getting tasks' ],
		[ 'order=s',     'column to order by, default id' ],
		[ 'direction=s', 'direction to order in, desc or asc, default desc' ],
		[ 'limit=s',     'limit on the number of tasks returned' ],
		$class->json_opts,
		$class->ini_opt,
	);
} ## end sub opt_spec

sub execute {
	my ( $self, $opt, $args ) = @_;

	my $cape_utils = $self->cape_utils($opt);

	if ( $opt->{count} ) {
		print $cape_utils->get_tasks_count( where => $opt->{where} ) . "\n";
	} elsif ( $opt->{json} ) {
		$self->print_json(
			$opt,
			$cape_utils->get_tasks(
				where     => $opt->{where},
				order     => $opt->{order},
				direction => $opt->{direction},
			)
		);
	} else {
		print $cape_utils->get_tasks_table(
			limit     => $opt->{limit},
			order     => $opt->{order},
			where     => $opt->{where},
			direction => $opt->{direction},
		);
	}

	return;
} ## end sub execute

1;
