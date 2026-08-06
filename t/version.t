#!perl

use strict;
use warnings;
use Test::More;
use CAPE::Utils                        ();
use CAPE::Utils::Cmd::Command::version ();

# "cape_utils version" must report the version of CAPE::Utils, that being the
# module the commands are backed by and the one the distribution is versioned
# from, rather than the App::Cmd glue in CAPE::Utils::Cmd
is( CAPE::Utils::Cmd::Command::version->version_package,
	'CAPE::Utils', 'the version command reports the version of CAPE::Utils' );

isnt( CAPE::Utils::Cmd::Command::version->version_package,
	'CAPE::Utils::Cmd', 'the version command does not report the App::Cmd glue version' );

# whatever it names has to actually carry a version, as App::Cmd calls ->VERSION
# on it and would otherwise print nothing useful
my $reported = CAPE::Utils::Cmd::Command::version->version_package->VERSION;
ok( defined($reported), 'the reported package carries a version' );
is( $reported, $CAPE::Utils::VERSION, 'the reported version is the CAPE::Utils one' );
like( $reported, qr/^[0-9]+\.[0-9]+\.[0-9]+$/, 'the reported version looks like a version' );

# it is still the App::Cmd version command underneath, so it keeps answering to
# both "version" and "--version"
isa_ok( 'CAPE::Utils::Cmd::Command::version', 'App::Cmd::Command::version' );
is_deeply(
	[ sort( CAPE::Utils::Cmd::Command::version->command_names ) ],
	[ sort qw( version --version ) ],
	'both version and --version still reach it'
);

done_testing;
