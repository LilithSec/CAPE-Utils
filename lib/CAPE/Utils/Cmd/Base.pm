package CAPE::Utils::Cmd::Base;

use strict;
use warnings;
use parent 'App::Cmd::Command';
use CAPE::Utils;
use JSON;

our $VERSION = '0.1.0';

# The option spec entry for the -i/--ini switch, which every sub command accepts
# for pointing at a config file other than the default.
#
# Kept here so the wording of the switch and its description only exists in one
# place, with each command including it in what its opt_spec returns.
#
# Args:
#     - none
#
# Returns a single array ref in the form Getopt::Long::Descriptive wants, that
# being the option spec string followed by the description shown in the usage
# output.
#
#     sub opt_spec {
#         my ($class) = @_;
#         return ( [ 'quiet|q', 'do not print anything' ], $class->ini_opt, );
#     }
sub ini_opt {
	return [ 'ini|i=s', 'config INI file, default /usr/local/etc/cape_utils.ini' ];
}

# The option spec entries for the --json and --pretty switches, used by the sub
# commands that can print their result as JSON instead of a table.
#
# Grouped into one call as the two always go together, --pretty being of no use
# without --json.
#
# Args:
#     - none
#
# Returns a list of two array refs in the form Getopt::Long::Descriptive wants,
# the first for --json and the second for --pretty. Meant to be returned as part
# of the list a command's opt_spec returns.
#
#     sub opt_spec {
#         my ($class) = @_;
#         return ( [ 'quiet|q', 'do not print anything' ], $class->json_opts, $class->ini_opt, );
#     }
sub json_opts {
	return ( [ 'json', 'output the result as JSON' ], [ 'pretty', 'pretty print the JSON output' ], );
}

# The CAPE::Utils object for the command being run, built on first use from the
# config file the user asked for and then kept for any later calls.
#
# Reading the config is not free and a command may need the object in both
# validate_args and execute, so it is built once per command object rather than
# per call site.
#
# Args:
#     - opt :: The options hash ref App::Cmd hands to validate_args and execute.
#       Only the 'ini' key is used, that being the path to the config file to
#       read. When it is undef CAPE::Utils falls back to its own default of
#       /usr/local/etc/cape_utils.ini. Required.
#
# Returns a CAPE::Utils object. Dies if the config file exists but can not be
# read or parsed, as CAPE::Utils->new does.
#
#     sub execute {
#         my ( $self, $opt, $args ) = @_;
#
#         my $cape_utils = $self->cape_utils($opt);
#         print $cape_utils->get_running_table;
#
#         return;
#     }
sub cape_utils {
	my ( $self, $opt ) = @_;

	if ( !defined( $self->{cape_utils} ) ) {
		$self->{cape_utils} = CAPE::Utils->new( $opt->{ini} );
	}

	return $self->{cape_utils};
}

# Prints a data structure to STDOUT as JSON, honoring the --pretty switch.
#
# Pretty printed JSON already ends in a newline, so one is only added for the
# compact form, keeping the output usable either way when piped into something
# like jq.
#
# Args:
#     - opt :: The options hash ref App::Cmd hands to execute. Only the 'pretty'
#       key is used, that being 0/1 for if the JSON should be pretty printed.
#       Required.
#
#     - data :: What to encode. Any structure JSON can encode, which in practice
#       is the hash ref or array ref a CAPE::Utils method returned. Required.
#
# Returns nothing, the point of it being what it prints.
#
#     $self->print_json( $opt, $cape_utils->get_running );
sub print_json {
	my ( $self, $opt, $data ) = @_;

	my $j = JSON->new;
	if ( $opt->{pretty} ) {
		$j->pretty(1);
	}
	print $j->encode($data);
	if ( !$opt->{pretty} ) {
		print "\n";
	}

	return;
} ## end sub print_json

1;
