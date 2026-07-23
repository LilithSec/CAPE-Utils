#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir tempfile );
use File::Slurp qw( read_file write_file );
use JSON        qw( decode_json );

use_ok('CAPE::Utils::Nergal') || print "Bail out!\n";

# duck typed stand in for Mojo::Upload
{

	package MockUpload;

	sub new {
		my ( $class, %args ) = @_;
		return bless {%args}, $class;
	}
	sub filename { return $_[0]->{filename}; }
	sub size     { return length( $_[0]->{content} ); }
	sub slurp    { return $_[0]->{content}; }

	sub move_to {
		my ( $self, $dest ) = @_;
		File::Slurp::write_file( $dest, $self->{content} );
		return 1;
	}
}

my $submitter = CAPE::Utils::Nergal->new;
isa_ok( $submitter, 'CAPE::Utils::Nergal' );

#
# checksums, checked against the well known digests of the string "abc"
#
my ( $fh, $filename ) = tempfile();
print {$fh} 'abc';
close($fh);

my $sums = $submitter->checksums($filename);
is( $sums->{sha256}, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'sha256 of "abc"' );
is( $sums->{sha1},   'a9993e364706816aba3e25717850c26c9cd0d89d',                         'sha1 of "abc"' );
is( $sums->{md5},    '900150983cd24fb0d6963f7d28e17f72',                                 'md5 of "abc"' );

#
# check_dirs
#
my $incoming = tempdir( CLEANUP => 1 );
foreach my $subdir (qw( sha256 json name_to_sha256 task_to_json tmp )) {
	mkdir( $incoming . '/' . $subdir );
}

my $checker = CAPE::Utils::Nergal->new( incoming => $incoming );
my $ok      = eval { $checker->check_dirs; };
ok( $ok && !$@, 'check_dirs passes when every required dir is present' );

# missing sub dir
rmdir( $incoming . '/tmp' );
eval { $checker->check_dirs; };
like( $@, qr/incoming tmp directory.*does not exist/, 'check_dirs dies on a missing sub dir' );
mkdir( $incoming . '/tmp' );

# missing incoming dir entirely
my $gone = CAPE::Utils::Nergal->new( incoming => $incoming . '/nope' );
eval { $gone->check_dirs; };
like( $@, qr/incoming directory.*does not exist/, 'check_dirs dies on a missing incoming dir' );

#
# receive, with the remote check and the actual CAPE submission mocked
#
my $ini = $incoming . '/cape_utils.ini';
write_file( $ini, "incoming=$incoming\n" );

my $submit_returns;
no warnings qw( redefine once );
local *CAPE::Utils::check_remote      = sub { return 1; };
local *CAPE::Utils::submit            = sub { my ( $self, %o ) = @_; return { $o{items}[0] => $submit_returns }; };
local *CAPE::Utils::LogDrek::openlog  = sub { };
local *CAPE::Utils::LogDrek::closelog = sub { };
local *CAPE::Utils::LogDrek::syslog   = sub { };
use warnings qw( redefine once );

my $receiver = CAPE::Utils::Nergal->new( ini => $ini );

# single task ID
$submit_returns = 99;
my $result = $receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => '{}',
	upload    => MockUpload->new( filename => 'single.bin', content => 'single sample' ),
	oversized => 0,
);
is( $result->{status}, 200,                         'receive returns 200 on a single task submission' );
is( $result->{body},   "Submitted as task ID 99\n", 'single task response body unchanged' );
ok( -l $incoming . '/task_to_json/99', 'task_to_json link created for the single task' );
my $single_json = decode_json( read_file( $incoming . '/json/single.bin' ) );
is( $single_json->{cape_submit}{task}, 99, '.cape_submit.task holds the single task ID' );

# multiple task IDs, as parsed from the newer CAPE fan out output
$submit_returns = '307616,307617,307618';
$result         = $receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => '{}',
	upload    => MockUpload->new( filename => 'multi.bin', content => 'multi sample' ),
	oversized => 0,
);
is( $result->{status}, 200, 'receive returns 200 on a fanned out submission' );
is( $result->{body},   "Submitted as task IDs 307616,307617,307618\n", 'fanned out response body lists all IDs' );
foreach my $task_id (qw( 307616 307617 307618 )) {
	ok( -l $incoming . '/task_to_json/' . $task_id, 'task_to_json link created for fanned out task ' . $task_id );
}
my $multi_json = decode_json( read_file( $incoming . '/json/multi.bin' ) );
is( $multi_json->{cape_submit}{task}, '307616,307617,307618', '.cape_submit.task holds the comma joined IDs' );

done_testing();
