#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir );
use File::Slurp qw( read_file write_file );
use JSON        qw( decode_json encode_json );

use_ok('CAPE::Utils::Nergal') || print "Bail out!\n";

#
# build a throwaway incoming dir + config pointing at it
#
my $incoming = tempdir( CLEANUP => 1 );
foreach my $subdir (qw( sha256 json name_to_sha256 task_to_json tmp )) {
	mkdir( $incoming . '/' . $subdir );
}
my $ini = $incoming . '/cape_utils.ini';
write_file( $ini, "incoming=$incoming\n" );

# lay down a fake submission the way receive() does: sample in sha256/, json in
# json/, a name_to_sha256 link to the sample, and a task_to_json link to the json
sub make_submission {
	my ( $name, $sha256, $task, $time ) = @_;
	my $sha256_file = $incoming . '/sha256/' . $sha256;
	write_file( $sha256_file, 'sample-' . $name );
	symlink( $sha256_file, $incoming . '/name_to_sha256/' . $name );
	my $json_file = $incoming . '/json/' . $name;
	write_file( $json_file,
		encode_json( { cape_submit => { name => $name, sha256 => $sha256, task => $task, time => $time } } )
			. "\n" );
	symlink( $json_file, $incoming . '/task_to_json/' . $task );
	return $json_file;
} ## end sub make_submission

#
# mock the actual CAPE submission and silence syslog
#
my $next_task = 0;
my $submitted_path;
no warnings qw( redefine once );
local *CAPE::Utils::submit = sub {
	my ( $self, %o ) = @_;
	$submitted_path = $o{items}[0];
	return { $o{items}[0] => $next_task };
};
local *CAPE::Utils::LogDrek::openlog  = sub { };
local *CAPE::Utils::LogDrek::closelog = sub { };
local *CAPE::Utils::LogDrek::syslog   = sub { };
use warnings qw( redefine once );

my $sub = CAPE::Utils::Nergal->new( ini => $ini );

#
# resubmit by task ID
#
make_submission( 'foo', ( 'a' x 64 ), 11, 1000 );
$next_task = 4242;
my $r = $sub->resub( task => 11 );
is( $r->{task},     4242, 'resub -r returns the new task ID' );
is( $r->{old_task}, 11,   'resub -r reports the previous task ID' );
is(
	$submitted_path,
	$incoming . '/name_to_sha256/foo',
	'resub submits via name_to_sha256 (preserving the original name), not the sha256 store'
);

my $foo = decode_json( read_file( $incoming . '/json/foo' ) );
is( $foo->{cape_submit}{task}, 4242, 'json .cape_submit.task updated to new task' );
is_deeply( $foo->{cape_submit}{task_orig}, [11],   '.cape_submit.task_orig holds the previous task' );
is_deeply( $foo->{cape_submit}{time_orig}, [1000], '.cape_submit.time_orig holds the previous time' );
isnt( $foo->{cape_submit}{time}, 1000, '.cape_submit.time was updated' );
ok( -l $incoming . '/task_to_json/4242', 'new task_to_json link created' );
is( readlink( $incoming . '/task_to_json/4242' ), $incoming . '/json/foo', 'new link points at the json' );
ok( -l $incoming . '/task_to_json/11', 'old task_to_json link is preserved' );

#
# resubmit by name
#
make_submission( 'baz', ( 'b' x 64 ), 3, 500 );
$next_task = 777;
my $r2 = $sub->resub( name => 'baz' );
is( $r2->{task},     777, 'resub -n returns the new task ID' );
is( $r2->{old_task}, 3,   'resub -n reports the previous task ID' );
ok( -l $incoming . '/task_to_json/777', 'new task_to_json link created for -n' );

#
# resubmission that CAPE fans out into multiple tasks
#
make_submission( 'fanout', ( 'e' x 64 ), 21, 2000 );
$next_task = '500,501';
my $r3 = $sub->resub( task => 21 );
is( $r3->{task},     '500,501', 'resub returns the comma joined task IDs on fan out' );
is( $r3->{old_task}, 21,        'resub reports the previous task ID' );
ok( -l $incoming . '/task_to_json/500', 'task_to_json link created for the first fanned out task' );
ok( -l $incoming . '/task_to_json/501', 'task_to_json link created for the second fanned out task' );

my $fanout = decode_json( read_file( $incoming . '/json/fanout' ) );
is( $fanout->{cape_submit}{task}, '500,501', '.cape_submit.task holds the comma joined task IDs' );

# resubmit by one ID of the fanned out submission
$next_task = 900;
my $r4 = $sub->resub( task => 501 );
is( $r4->{old_task}, '500,501', 'resub by one fanned out ID finds the submission' );
is( $r4->{task},     900,       'resub by one fanned out ID returns the new task ID' );

$fanout = decode_json( read_file( $incoming . '/json/fanout' ) );
is_deeply( $fanout->{cape_submit}{task_orig}, [ 21, '500,501' ], '.cape_submit.task_orig holds the fanned out IDs' );

#
# guards / error paths
#
eval { $sub->resub( name => 'x', task => 1 ); };
like( $@, qr/only one of/, 'dies when both -n and -r are given' );

eval { $sub->resub(); };
like( $@, qr/requires one of/, 'dies when neither key is given' );

eval { $sub->resub( task => 99999 ); };
like( $@, qr/no task_to_json link for task/, 'dies on an unknown task ID' );

# a stale task ID pointing at a json that describes a different task
make_submission( 'bar', ( 'c' x 64 ), 99, 100 );
symlink( $incoming . '/json/bar', $incoming . '/task_to_json/7' );
eval { $sub->resub( task => 7 ); };
like( $@, qr/was overwritten by a newer submission/, 'dies when the json no longer describes the requested task' );

# json present but the sha256 sample is gone
make_submission( 'nosample', ( 'd' x 64 ), 55, 10 );
unlink( $incoming . '/sha256/' . ( 'd' x 64 ) );
eval { $sub->resub( task => 55 ); };
like( $@, qr/sample missing/, 'dies when the sha256 sample is missing' );

done_testing();
