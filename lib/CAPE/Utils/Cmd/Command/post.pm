package CAPE::Utils::Cmd::Command::post;

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
#     print CAPE::Utils::Cmd::Command::post->abstract . "\n";
sub abstract {
	return 'perform the post actions for a run';
}

# The usage block App::Cmd prints for "cape_utils help post" and on a usage
# error. The first line is the synopsis, in which %c is replaced with the name
# the script was invoked as, and the rest is the longer description.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::post->usage_desc;
sub usage_desc {
	return '%c post [-d] -r ID

Performs the configured post actions for the specified run ID.

See CAPE::Utils->post for more information.
';
}

# The switches this sub command takes, those being -r for the run to work on, -d
# for showing what would happen instead of doing it, and the shared -i/--ini.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::post->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return ( [ 'r=i', 'the run ID to post process' ], [ 'd', 'describe the actions to be taken' ], $class->ini_opt, );
}

# Checks a run ID was given before execute is reached. This applies to -d as
# well, which describes the actions for a run rather than in the abstract.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. Only 'r' is looked at,
#       that being the run ID. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing when the arguments are usable. Calls usage_error, which prints
# the usage and exits non zero, when -r was not given.
#
#     $ cape_utils post
#     No run ID specified via -r
sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $opt->{'r'} ) ) {
		$self->usage_error('No run ID specified via -r');
	}

	return;
}

# Runs the sub command, either describing the configured post actions or
# performing them for the run via CAPE::Utils->post.
#
# -d only prints the three config settings that decide which actions run, as the
# post actions include removing the stored binary and being able to check what is
# turned on without triggering that is worth having.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'r' is the run ID, 'd'
#       is 0/1 for describing rather than doing, and 'ini' is the config file to
#       use. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing, the point of it being what it prints or does. Dies if the
# config can not be read. Failures of the individual post actions are logged and
# warned about by post() rather than being fatal.
#
#     $ cape_utils post -d -r 1
#     munge: 1
#     post_link: 0
#     post_bin_rm: 0
#
#     $ cape_utils post -r 1
sub execute {
	my ( $self, $opt, $args ) = @_;

	my $cape_utils = $self->cape_utils($opt);

	if ( $opt->{'d'} ) {
		print 'munge: ' . $cape_utils->{'config'}{'_'}{'post_munge'} . "\n";
		print 'post_link: ' . $cape_utils->{'config'}{'_'}{'post_link'} . "\n";
		print 'post_bin_rm: ' . $cape_utils->{'config'}{'_'}{'post_bin_rm'} . "\n";

		return;
	}

	$cape_utils->post( 'id' => $opt->{'r'} );

	return;
} ## end sub execute

1;
