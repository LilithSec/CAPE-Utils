package CAPE::Utils::Cmd::Command::resub;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';
use CAPE::Utils::MojoSubmit ();

our $VERSION = '0.1.0';

sub abstract {
	return 'resubmit a sample previously submitted via mojo_cape_submit';
}

sub usage_desc {
	return 'cape_utils resub [-i <config>] ( -n <incoming name> | -r <task ID> ) [--json] [--pretty]

Resubmit a sample that was originally submitted via mojo_cape_submit, located
by either its incoming name (-n) or a task ID (-r). As the incoming JSON store
is keyed by name and overwritten per name, -n targets the most recent
submission made under that name, while -r resolves the exact JSON the task was
linked to.

The previous time and task are preserved under .cape_submit.time_orig and
.cape_submit.task_orig, the incoming JSON is updated atomically, and a new
task_to_json link is created for the new task ID.

See CAPE::Utils::MojoSubmit->resub for more information.
';
} ## end sub usage_desc

sub opt_spec {
	my ($class) = @_;
	return (
		[ 'n=s', 'incoming name to resubmit (most recent submission under that name)' ],
		[ 'r=i', 'task ID to resubmit' ],
		$class->json_opts, $class->ini_opt,
	);
}

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

sub execute {
	my ( $self, $opt, $args ) = @_;

	my $result = CAPE::Utils::MojoSubmit->new( ini => $opt->{ini} )->resub(
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
