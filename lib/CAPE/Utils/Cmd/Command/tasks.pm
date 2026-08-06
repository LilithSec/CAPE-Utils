package CAPE::Utils::Cmd::Command::tasks;

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
#     print CAPE::Utils::Cmd::Command::tasks->abstract . "\n";
sub abstract {
	return 'show tasks';
}

# The usage block App::Cmd prints for "cape_utils help tasks" and on a usage
# error. The first line is the synopsis and the rest is the longer description.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::tasks->usage_desc;
sub usage_desc {
	return 'cape_utils tasks [-i <config>] [-C] [-w <where>] [--direction> <dir>]
    [--order <column>] [--limit <limit>] [--json] [--pretty]


Show CAPE tasks.
';
}

# The switches this sub command takes. Unlike pending and running, tasks covers
# every task regardless of state, so it also takes the ordering and limiting
# switches needed to make that usable.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::tasks->opt_spec;
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

# Runs the sub command, printing the tasks in one of three forms.
#
# -C wins over --json, as asking for the count is asking for a single number, and
# with neither the table is printed. --limit only applies to the table, the JSON
# form being meant for feeding something else that can do its own limiting.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'count' is 0/1 for
#       printing the count instead, 'where' is a SQL fragment such as
#       'status = "reported"', 'order' is the column to sort on, 'direction' is
#       'asc' or 'desc', 'limit' caps how many rows the table shows, 'json' and
#       'pretty' control the JSON output, and 'ini' is the config file to use.
#       Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing, the point of it being what it prints. Dies if the config can
# not be read or the database call fails.
#
#     $ cape_utils tasks -C
#     $ cape_utils tasks --order id --direction asc --limit 20
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
