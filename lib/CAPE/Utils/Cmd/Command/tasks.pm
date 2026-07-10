package CAPE::Utils::Cmd::Command::tasks;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

=head1 NAME

CAPE::Utils::Cmd::Command::tasks - Show CAPE tasks.

=head1 VERSION

0.1.0

=cut

our $VERSION = '0.1.0';

=head1 SYNOPSIS

cape_utils tasks [B<-i> <config>] [B<-C>] [B<-w> <where>] [B<--direction> <dir>]
[B<--order> <column>] [B<--limit> <limit>] [B<--json>] [B<--pretty>]

=head1 METHODS

=head2 abstract

Returns the one line description used by the command listing.

=cut

sub abstract {
	return 'show tasks';
}

=head2 usage_desc

Returns the usage string shown in help output.

=cut

sub usage_desc {
	return '%c tasks %o';
}

=head2 opt_spec

Returns the L<Getopt::Long::Descriptive> option spec for this command.

=over 4

=item * B<-C> - Print the task count instead of the table.

=item * B<--direction> <dir> - Direction to order in, desc or asc. Default :: desc

=item * B<--order> <column> - Column to order by. Default :: id

=item * B<--limit> <limit> - Limit on the number of tasks returned.

=item * B<-w> <where> - Additional SQL args for use with the statement getting tasks.

=back

=cut

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

=head2 execute

Runs the command.

=cut

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
