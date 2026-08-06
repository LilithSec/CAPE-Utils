package CAPE::Utils::Cmd::Command::fail;

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
#     print CAPE::Utils::Cmd::Command::fail->abstract . "\n";
sub abstract {
	return 'fail pending tasks';
}

# The usage block App::Cmd prints for "cape_utils help fail" and on a usage
# error. The first line is the synopsis, in which %c is replaced with the name
# the script was invoked as, and the rest is the longer description.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::fail->usage_desc;
sub usage_desc {
	return '%c fail -w "id = 404"

Uses the specified where statement to fail pending items.

Unless fail_all is set to 1 in the config, where must be given.
';
}

# The switches this sub command takes, those being -w/--where for narrowing down
# what gets failed and the shared -i/--ini.
#
# Whether a where statement is required is left to CAPE::Utils->fail, which dies
# without one unless fail_all is enabled in the config, so the check lives in one
# place rather than being repeated here.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::fail->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return ( [ 'where|w=s', 'additional SQL args for use when failing pending items' ], $class->ini_opt, );
}

# Runs the sub command, failing the matching pending tasks and printing the
# summary CAPE::Utils->fail returns.
#
# Args:
#     - opt :: The options hash ref built from opt_spec. 'where' is the SQL
#       fragment limiting what is failed, such as 'id = 404', and 'ini' is the
#       config file to use. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing, the point of it being what it prints. Dies if no where
# statement was given and fail_all is not enabled, or if the database call fails.
#
#     $ cape_utils fail -w "id = 404"
sub execute {
	my ( $self, $opt, $args ) = @_;

	print $self->cape_utils($opt)->fail( where => $opt->{where} );

	return;
}

1;
