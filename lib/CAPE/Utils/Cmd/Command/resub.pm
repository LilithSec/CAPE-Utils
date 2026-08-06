package CAPE::Utils::Cmd::Command::resub;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';
use CAPE::Utils::Nergal ();

our $VERSION = '0.1.0';

# The one line summary App::Cmd shows beside this sub command in the listing
# printed by "cape_utils commands" and by the top level usage output.
#
# Args:
#     - none
#
# Returns the summary as a string, with no trailing newline.
#
#     print CAPE::Utils::Cmd::Command::resub->abstract . "\n";
sub abstract {
	return 'resubmit a sample previously submitted via nergal';
}

# The usage block App::Cmd prints for "cape_utils help resub" and on a usage
# error. The first line is the synopsis and the rest is the longer description,
# which spells out how -n and -r differ as the incoming JSON store being keyed by
# name makes that a real distinction and not just two ways of saying the same
# thing.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::resub->usage_desc;
sub usage_desc {
	return 'cape_utils resub [-i <config>] ( -n <incoming name> | -r <task ID> ) [--json] [--pretty]

Resubmit a sample that was originally submitted via nergal, located
by either its incoming name (-n) or a task ID (-r). As the incoming JSON store
is keyed by name and overwritten per name, -n targets the most recent
submission made under that name, while -r resolves the exact JSON the task was
linked to.

The previous time and task are preserved under .cape_submit.time_orig and
.cape_submit.task_orig, the incoming JSON is updated atomically, and a new
task_to_json link is created for the new task ID.

See CAPE::Utils::Nergal->resub for more information.
';
} ## end sub usage_desc

# The switches this sub command takes, those being the two ways of naming what to
# resubmit plus the shared JSON and config switches.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::resub->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return (
		[ 'n=s', 'incoming name to resubmit (most recent submission under that name)' ],
		[ 'r=i', 'task ID to resubmit' ],
		$class->json_opts, $class->ini_opt,
	);
}

# Checks exactly one of -n or -r was given before execute is reached.
#
# Both are rejected rather than picking one, as they can point at different
# samples and silently going with either would be resubmitting something the user
# did not ask for.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'n' is the incoming
#       name and 'r' is the task ID. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing when the arguments are usable. Calls usage_error, which prints
# the usage and exits non zero, when both or neither were given.
#
#     $ cape_utils resub -n foo -r 1
#     -n and -r are mutually exclusive
sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( defined( $opt->{n} ) && defined( $opt->{r} ) ) {
		$self->usage_error('-n and -r are mutually exclusive');
	}
	if ( !defined( $opt->{n} ) && !defined( $opt->{r} ) ) {
		$self->usage_error('one of -n (incoming name) or -r (task ID) is required');
	}

	return;
} ## end sub validate_args

# Runs the sub command, resubmitting the sample via CAPE::Utils::Nergal->resub.
#
# A CAPE::Utils::Nergal is built directly rather than going through the inherited
# cape_utils helper, as the incoming store this works on belongs to nergal and
# not to CAPE::Utils.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. Exactly one of 'n' or
#       'r' is set, validate_args having already seen to that, 'json' and
#       'pretty' control the JSON output, and 'ini' is the config file to use.
#       Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing, the point of it being what it prints, that being either the
# hash ref resub() returned as JSON or a one line summary of the old and new
# task. Dies if the config can not be read, nothing matches what was asked for,
# or the resubmission itself fails.
#
#     $ cape_utils resub -r 1
#     Resubmitted "foo" (sha256 ...) as task 2, previously task 1
sub execute {
	my ( $self, $opt, $args ) = @_;

	my $result = CAPE::Utils::Nergal->new( ini => $opt->{ini} )->resub(
		name => $opt->{n},
		task => $opt->{r},
	);

	if ( $opt->{json} ) {
		$self->print_json( $opt, $result );
	} else {
		print 'Resubmitted "'
			. $result->{name}
			. '" (sha256 '
			. $result->{sha256}
			. ') as task '
			. $result->{task}
			. ', previously task '
			. ( defined( $result->{old_task} ) ? $result->{old_task} : 'undef' ) . "\n";
	} ## end else [ if ( $opt->{json} ) ]

	return;
} ## end sub execute

1;
