#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir );
use File::Slurp qw( write_file );

use_ok('CAPE::Utils') || print "Bail out!\n";

#
# build a throwaway base dir + config pointing at it so chdir in poetry works
#
my $base         = tempdir( CLEANUP => 1 );
my $current_user = getpwuid($>);
my $poetry_ini   = $base . '/poetry.ini';
write_file( $poetry_ini, "base=$base\npoetry=1\npoetry_path=/etc/poetry/bin/poetry\ncape_runas=$current_user\n" );

#
# mock the command invocation... capture the command that would have run and
# emit canned output/success
#
my $captured_command;
my $canned_output  = "installing\n";
my $canned_success = 1;
no warnings qw( redefine once );
local *CAPE::Utils::run = sub {
	my (%run_opts) = @_;
	$captured_command = $run_opts{command};
	return ( $canned_success, undef, [$canned_output], [$canned_output], [] );
};
use warnings qw( redefine once );

my $poetry_cape = CAPE::Utils->new($poetry_ini);

#
# args are passed straight to poetry_path (no "run" wrapping like exec)
#
my $results = $poetry_cape->poetry( args => ['install'], quiet => 1 );
is_deeply( $captured_command, [ '/etc/poetry/bin/poetry', 'install' ], 'args handed straight to poetry' );
is( $results->{success}, 1,              'success reflected as 1' );
is( $results->{output},  "installing\n", 'output captured' );

#
# multi-arg passthrough
#
$poetry_cape->poetry( args => [ 'add', 'requests' ], quiet => 1 );
is_deeply(
	$captured_command,
	[ '/etc/poetry/bin/poetry', 'add', 'requests' ],
	'multiple args passed through to poetry'
);

#
# a failing command is reflected as success => 0
#
$canned_success = 0;
$results        = $poetry_cape->poetry( args => ['lock'], quiet => 1 );
is( $results->{success}, 0, 'failing command reflected as success => 0' );
$canned_success = 1;

#
# poetry disabled (poetry=0) dies before running anything
#
my $disabled_ini = $base . '/disabled.ini';
write_file( $disabled_ini, "base=$base\npoetry=0\ncape_runas=$current_user\n" );
my $disabled_cape = CAPE::Utils->new($disabled_ini);
eval { $disabled_cape->poetry( args => ['install'], quiet => 1 ); };
like( $@, qr/python_mgr is none/, 'poetry dies when poetry=0' );

#
# running as the wrong user with enable_sudo set prepends "sudo -u <cape_runas>"
#
my $sudo_ini = $base . '/sudo.ini';
write_file( $sudo_ini,
	"base=$base\npoetry=1\npoetry_path=/etc/poetry/bin/poetry\ncape_runas=nope_not_this_user\nenable_sudo=1\n" );
my $sudo_cape = CAPE::Utils->new($sudo_ini);
$sudo_cape->poetry( args => ['install'], quiet => 1 );
is_deeply(
	$captured_command,
	[ 'sudo', '-u', 'nope_not_this_user', '/etc/poetry/bin/poetry', 'install' ],
	'poetry prepends "sudo -u <cape_runas>" when enable_sudo is set and not the configured user'
);

#
# verbose mode reports what it is doing on STDERR without touching the output
#
my $stderr_buffer = '';
{
	open( my $save_stderr, '>&', \*STDERR ) || die("Unable to dup STDERR: $!");
	close(STDERR);
	open( STDERR, '>', \$stderr_buffer ) || die("Unable to redirect STDERR: $!");
	my $verbose_results = $poetry_cape->poetry( args => ['install'], quiet => 1, verbose => 1 );
	open( STDERR, '>&', $save_stderr ) || die("Unable to restore STDERR: $!");
	close($save_stderr);

	like( $stderr_buffer, qr/changing directory to/, 'verbose reports the chdir on STDERR' );
	like(
		$stderr_buffer,
		qr{running command:.*/etc/poetry/bin/poetry install},
		'verbose reports the full command on STDERR'
	);
	like( $stderr_buffer, qr/command succeeded/, 'verbose reports the exit status on STDERR' );
	is( $verbose_results->{output}, "installing\n", 'verbose does not pollute the returned output' );
}

#
# missing args dies
#
eval { $poetry_cape->poetry( args => [], quiet => 1 ); };
ok( $@, 'poetry dies when no args are passed' );

#
# poetry() refuses to run when python_mgr is uv, so poetry args never reach uv
#
my $uv_ini = $base . '/uv.ini';
write_file( $uv_ini, "base=$base\npython_mgr=uv\ncape_runas=$current_user\n" );
my $uv_cape = CAPE::Utils->new($uv_ini);
undef($captured_command);
eval { $uv_cape->poetry( args => ['install'], quiet => 1 ); };
like( $@, qr/Arguments are for poetry, but python_mgr is uv/, 'poetry dies when python_mgr is uv' );
ok( !defined($captured_command), 'nothing ran when poetry was refused' );

#
# python_mgr hands args straight to uv at its default path
#
$results = $uv_cape->python_mgr( args => [ 'pip', 'list' ], manager => 'uv', quiet => 1 );
is_deeply( $captured_command, [ '/usr/local/bin/uv', 'pip', 'list' ], 'args handed straight to uv' );
is( $results->{success}, 1, 'uv success reflected as 1' );

#
# python_mgr with no manager given runs whichever is configured
#
$poetry_cape->python_mgr( args => ['lock'], quiet => 1 );
is_deeply(
	$captured_command,
	[ '/etc/poetry/bin/poetry', 'lock' ],
	'python_mgr without manager uses the configured one'
);

#
# the uv sub command is the poetry one with the manager swapped
#
use_ok('CAPE::Utils::Cmd::Command::uv');
is( CAPE::Utils::Cmd::Command::poetry->manager, 'poetry', 'poetry sub command manager' );
is( CAPE::Utils::Cmd::Command::uv->manager,     'uv',     'uv sub command manager' );

done_testing();
