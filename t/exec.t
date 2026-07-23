#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir );
use File::Slurp qw( write_file );

use_ok('CAPE::Utils') || print "Bail out!\n";

#
# build a throwaway base dir + config pointing at it so chdir in exec works
#
my $base = tempdir( CLEANUP => 1 );
my $ini  = $base . '/cape_utils.ini';
write_file( $ini, "base=$base\npoetry=0\n" );

#
# mock the command invocation... capture the command that would have run and
# emit canned output/success
#
my $captured_command;
my $canned_output  = "hello\n";
my $canned_success = 1;
no warnings qw( redefine once );
local *CAPE::Utils::run = sub {
	my (%run_opts) = @_;
	$captured_command = $run_opts{command};
	return ( $canned_success, undef, [$canned_output], [$canned_output], [] );
};
use warnings qw( redefine once );

my $cape_util = CAPE::Utils->new($ini);

#
# poetry disabled -> command is run verbatim
#
my $results = $cape_util->exec( command => [ 'echo', 'hello' ], quiet => 1 );
is_deeply( $captured_command, [ 'echo', 'hello' ], 'command run verbatim when poetry disabled' );
is( $results->{success}, 1,         'success reflected as 1' );
is( $results->{output},  "hello\n", 'output captured' );

#
# a failing command is reflected as success => 0
#
$canned_success = 0;
$results        = $cape_util->exec( command => ['false'], quiet => 1 );
is( $results->{success}, 0, 'failing command reflected as success => 0' );

#
# poetry enabled -> command is wrapped in "poetry run"
#
$canned_success = 1;
write_file( $ini, "base=$base\npoetry=1\npoetry_path=/etc/poetry/bin/poetry\n" );
my $poetry_cape = CAPE::Utils->new($ini);
$poetry_cape->exec( command => [ 'python3', 'utils/process.py' ], quiet => 1 );
is_deeply(
	$captured_command,
	[ '/etc/poetry/bin/poetry', 'run', 'python3', 'utils/process.py' ],
	'command wrapped in poetry run when poetry enabled'
);

#
# a missing command dies
#
eval { $cape_util->exec( command => [], quiet => 1 ); };
ok( $@, 'exec dies when no command is passed' );

done_testing();
