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
my $base         = tempdir( CLEANUP => 1 );
my $current_user = getpwuid($>);
my $ini          = $base . '/cape_utils.ini';
write_file( $ini, "base=$base\npoetry=0\ncape_runas=$current_user\n" );

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
my $poetry_ini = $base . '/poetry.ini';
write_file( $poetry_ini, "base=$base\npoetry=1\npoetry_path=/etc/poetry/bin/poetry\ncape_runas=$current_user\n" );
my $poetry_cape = CAPE::Utils->new($poetry_ini);
$poetry_cape->exec( command => [ 'python3', 'utils/process.py' ], quiet => 1 );
is_deeply(
	$captured_command,
	[ '/etc/poetry/bin/poetry', 'run', 'python3', 'utils/process.py' ],
	'command wrapped in poetry run when poetry enabled'
);

#
# running as the wrong user with enable_sudo unset dies
#
my $wrong_ini = $base . '/wrong_user.ini';
write_file( $wrong_ini, "base=$base\npoetry=0\ncape_runas=nope_not_this_user\nenable_sudo=0\n" );
my $wrong_cape = CAPE::Utils->new($wrong_ini);
eval { $wrong_cape->exec( command => ['echo'], quiet => 1 ); };
like( $@, qr/Not being ran as the configured user/, 'exec dies when not the configured user and enable_sudo is unset' );

#
# running as the wrong user with enable_sudo set prepends "sudo -u <cape_runas>"
#
my $sudo_ini = $base . '/sudo.ini';
write_file( $sudo_ini, "base=$base\npoetry=0\ncape_runas=nope_not_this_user\nenable_sudo=1\n" );
my $sudo_cape = CAPE::Utils->new($sudo_ini);
$sudo_cape->exec( command => [ 'echo', 'hello' ], quiet => 1 );
is_deeply(
	$captured_command,
	[ 'sudo', '-u', 'nope_not_this_user', 'echo', 'hello' ],
	'exec prepends "sudo -u <cape_runas>" when enable_sudo is set and not the configured user'
);

#
# a missing command dies
#
eval { $cape_util->exec( command => [], quiet => 1 ); };
ok( $@, 'exec dies when no command is passed' );

done_testing();
