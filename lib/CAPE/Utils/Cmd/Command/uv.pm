package CAPE::Utils::Cmd::Command::uv;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Command::poetry';

our $VERSION = '0.1.0';

# The uv sub command. Everything but the manager name and the help text comes
# from the poetry sub command, which it subclasses.

# The Python manager this sub command hands its arguments to.
#
# Args:
#     - none
#
# Returns 'uv', matching the python_mgr config value.
#
#     print CAPE::Utils::Cmd::Command::uv->manager . "\n";    # uv
sub manager {
	return 'uv';
}

# The one line summary App::Cmd shows beside this sub command in the listing
# printed by "cape_utils commands" and by the top level usage output.
#
# Args:
#     - none
#
# Returns the summary as a string, with no trailing newline.
#
#     print CAPE::Utils::Cmd::Command::uv->abstract . "\n";
sub abstract {
	return 'run an arbitrary uv command in the CAPE base dir as the cape user';
}

# The usage block App::Cmd prints for "cape_utils help uv" and on a usage error.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline. The option
# list built from opt_spec is appended to it by App::Cmd.
#
#     print CAPE::Utils::Cmd::Command::uv->usage_desc;
sub usage_desc {
	return 'cape_utils uv [-i <config>] [--quiet] [--verbose] [--json] [--pretty] -- <arg>...

Run an arbitrary uv command from the CAPE base directory as the configured
cape_runas user. Unlike "exec", which wraps the command in "uv run", the
arguments are handed straight to uv, so anything uv accepts may be run.

python_mgr must be uv in the config, otherwise this dies.

Use "--" to separate cape_utils options from uv and its arguments so that
flags meant for uv are not parsed by cape_utils, e.g.

    cape_utils uv -- sync
    cape_utils uv -- pip list
    cape_utils uv -- run python3 utils/process.py -r 1
';
} ## end sub usage_desc

1;
