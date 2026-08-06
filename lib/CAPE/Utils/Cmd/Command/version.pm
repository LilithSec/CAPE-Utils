package CAPE::Utils::Cmd::Command::version;

use strict;
use warnings;
use parent 'App::Cmd::Command::version';
use CAPE::Utils ();

our $VERSION = '0.1.0';

# The package "cape_utils version" reports the version of, overriding the
# App::Cmd default of the application class.
#
# Out of the box App::Cmd reports CAPE::Utils::Cmd, which is just the App::Cmd
# glue and carries a version of its own that says nothing about what the commands
# can actually do. The useful answer is the version of CAPE::Utils, that being
# the module the commands are all backed by and the one the distribution is
# versioned from, so a bug report saying "version 5.0.0" means something.
#
# Args:
#     - none
#
# Returns the package name to report the version of, as a string. App::Cmd calls
# ->VERSION on it and prints that.
#
#     $ cape_utils version
#     cape_utils (CAPE::Utils) version 5.0.0 (/usr/local/bin/cape_utils)
sub version_package {
	return 'CAPE::Utils';
}

1;
