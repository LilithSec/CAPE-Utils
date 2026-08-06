package CAPE::Utils::Cmd::Command::eve;

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
#     print CAPE::Utils::Cmd::Command::eve->abstract . "\n";
sub abstract {
	return 'invoke CAPE::Utils->eve_process';
}

# The usage block App::Cmd prints for "cape_utils help eve" and on a usage
# error. The first line is the synopsis, in which %c is replaced with the name
# the script was invoked as, and the rest is the longer description.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::eve->usage_desc;
sub usage_desc {
	return '%c eve

Calls CAPE::Utils->eve_process to update the EVE file.
';
}

# The switches this sub command takes, which is just the shared -i/--ini for
# pointing at a config file, as everything else it needs comes from that config.
#
# Args:
#     - none beyond the invoking class, which App::Cmd also hands the
#       application object as a second argument, unused here.
#
# Returns a list of array refs in the form Getopt::Long::Descriptive wants, each
# being an option spec string followed by its usage description.
#
#     my @spec = CAPE::Utils::Cmd::Command::eve->opt_spec;
sub opt_spec {
	my ($class) = @_;
	return ( $class->ini_opt, );
}

# Runs the sub command, processing CAPE's eve.json via CAPE::Utils->eve_process.
#
# Meant to be ran periodically rather than as a daemon, the provided systemd
# timer being one way of doing that.
#
# Args:
#     - opt :: The options hash ref built from opt_spec, of which only 'ini' is
#       used here. Required, and supplied by App::Cmd.
#
#     - args :: An array ref of the leftover positional arguments. This sub
#       command takes none, so it is ignored. Required, and supplied by App::Cmd.
#
# Returns nothing. Dies if the config can not be read or eve_process fails.
#
#     $ cape_utils eve -i /usr/local/etc/cape_utils.ini
sub execute {
	my ( $self, $opt, $args ) = @_;

	$self->cape_utils($opt)->eve_process();

	return;
}

1;
