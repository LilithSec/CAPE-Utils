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
# parse_name
#
my $good_sha1 = 'a9993e364706816aba3e25717850c26c9cd0d89d';
my $extracted = 1753599990;

# the digest field is a full sha1 from current submitters but the first 18
# characters of the md5 from older ones, so no particular length is required

my $parsed
	= $submitter->parse_name(
		'192.168.14.42-80-192.168.14.2-60729-TCP-335835d5cc1cde63a8-vvelox-1780421209-application_x-msdownload');
is_deeply(
	$parsed,
	{
		src_ip    => '192.168.14.42',
		src_port  => 80,
		dest_ip   => '192.168.14.2',
		dest_port => 60729,
		proto     => 'TCP',
		sha1      => '335835d5cc1cde63a8',
		slug      => 'vvelox',
		time      => 1780421209,
		timestamp => '2026-06-02T17:26:49Z',
		mime      => 'application_x-msdownload',
	},
	'parse_name pulls every field out of a standard name'
);

# the mime is the only field that may hold a '-', which the limit of 9 preserves
$parsed
	= $submitter->parse_name( '192.168.1.5-49152-93.184.216.34-80-TCP-'
		. $good_sha1
		. '-acme-'
		. $extracted
		. '-application_x-ms-dos-executable' );
is( $parsed->{mime}, 'application_x-ms-dos-executable', 'parse_name keeps a mime holding a "-"' );
is( $parsed->{time}, $extracted,                        'parse_name takes the epoch from field 7' );

# the epoch is always UTC, regardless of what the local zone happens to be
foreach my $zone (qw( UTC America/Chicago Australia/Sydney )) {
	local $ENV{TZ} = $zone;
	my $utc
		= $submitter->parse_name(
			'10.0.0.1-1234-10.0.0.2-80-TCP-' . $good_sha1 . '-foo-' . $extracted . '-application_pdf' );
	is( $utc->{timestamp}, '2025-07-27T07:06:30Z', 'parse_name renders the epoch as UTC under TZ=' . $zone );
}

# hex is accepted upper, lower, or mixed, and normalized down so it compares
# against the lowercase digests checksums() generates
foreach my $variant ( uc($good_sha1), ucfirst($good_sha1) ) {
	$parsed
		= $submitter->parse_name(
			'10.0.0.1-1234-10.0.0.2-80-TCP-' . $variant . '-foo-' . $extracted . '-application_pdf' );
	is( $parsed->{sha1}, $good_sha1, 'parse_name lower cases the sha1 given "' . substr( $variant, 0, 8 ) . '..."' );
}

# proto likewise matches without regard to case and comes back upper cased
foreach my $variant (qw( TCP tcp UDP udp )) {
	$parsed
		= $submitter->parse_name(
			'10.0.0.1-1234-10.0.0.2-80-' . $variant . '-' . $good_sha1 . '-foo-' . $extracted . '-application_pdf' );
	is( $parsed->{proto}, uc($variant), 'parse_name accepts and upper cases proto "' . $variant . '"' );
}

$parsed
	= $submitter->parse_name(
		'2001:db8::1-49152-2606:2800:220::1-443-TCP-' . $good_sha1 . '-foo-' . $extracted . '-text_x-shellscript' );
is( $parsed->{src_ip},  '2001:db8::1',      'parse_name handles an IPv6 source' );
is( $parsed->{dest_ip}, '2606:2800:220::1', 'parse_name handles an IPv6 destination' );

# anything not valid in full parses to nothing rather than a partial hash
my %bad = (
	'a plain name'         => 'invoice.doc',
	'too few fields'       => 'lilith-manual-sample.exe',
	'no mime'              => '192.168.1.5-49152-93.184.216.34-80-TCP-' . $good_sha1 . '-foo-' . $extracted,
	'mime with no "_"'     => '10.0.0.1-1234-10.0.0.2-80-TCP-' . $good_sha1 . '-foo-' . $extracted . '-applicationpdf',
	'empty src port'       => '192.168.1.5--93.184.216.34-80-TCP-' . $good_sha1 . '-foo-' . $extracted . '-app_pdf',
	'port over 65535'      => '10.0.0.1-99999-10.0.0.2-80-TCP-' . $good_sha1 . '-foo-' . $extracted . '-app_pdf',
	'non hex sha1'         => '10.0.0.1-1234-10.0.0.2-80-TCP-nothexz-foo-' . $extracted . '-app_pdf',
	'proto not TCP or UDP' => '10.0.0.1-1234-10.0.0.2-80-ICMP-' . $good_sha1 . '-foo-' . $extracted . '-app_pdf',
	'src ip not an ip'     => 'notanip-1234-10.0.0.2-80-TCP-' . $good_sha1 . '-foo-' . $extracted . '-app_pdf',
	'dest ip out of range' => '10.0.0.1-1234-999.1.1.1-80-TCP-' . $good_sha1 . '-foo-' . $extracted . '-app_pdf',
	'all digit slug'       => '10.0.0.1-1234-10.0.0.2-80-TCP-' . $good_sha1 . '-12345-' . $extracted . '-app_pdf',
	'epoch of zero'        => '10.0.0.1-1234-10.0.0.2-80-TCP-' . $good_sha1 . '-foo-0-app_pdf',
	'non numeric epoch'    => '10.0.0.1-1234-10.0.0.2-80-TCP-' . $good_sha1 . '-foo-later-app_pdf',
	'trailing newline'     => '10.0.0.1-1234-10.0.0.2-80-TCP-' . $good_sha1 . '-foo-' . $extracted . "-app_pdf\n",

	# a slug holding a '-' shifts every later field, so it must decline outright
	# rather than silently mis-parse into the wrong fields
	'slug holding a "-"' => '10.0.0.1-1234-10.0.0.2-80-TCP-' . $good_sha1 . '-acme-corp-' . $extracted . '-app_pdf',
);
foreach my $case ( sort( keys(%bad) ) ) {
	is( $submitter->parse_name( $bad{$case} ), undef, 'parse_name declines ' . $case );
}

is( $submitter->parse_name(undef), undef, 'parse_name declines an undef name' );

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

#
# padding from the submission name, for tools submitting in the standard format
# without the JSON body that normally carries the flow info and slug
#
$submit_returns = 1;
my $std_name
	= '192.168.1.5-49152-93.184.216.34-80-TCP-' . $good_sha1 . '-acme-' . $extracted . '-application_x-dosexec';
$receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => undef,
	upload    => MockUpload->new( filename => $std_name, content => 'no json body at all' ),
	oversized => 0,
);
my $padded = decode_json( read_file( $incoming . '/json/' . $std_name ) );
is( $padded->{src_ip},                        '192.168.1.5',           'padded .src_ip' );
is( $padded->{src_port},                      49152,                   'padded .src_port' );
is( $padded->{dest_ip},                       '93.184.216.34',         'padded .dest_ip' );
is( $padded->{dest_port},                     80,                      'padded .dest_port' );
is( $padded->{proto},                         'TCP',                   'padded .proto' );
is( $padded->{suricata_extract_submit}{slug}, 'acme',                  'padded the slug out of the name' );
is( $padded->{suricata_extract_submit}{sha1}, $good_sha1,              'padded the pre send sha1 out of the name' );
is( $padded->{suricata_extract_submit}{time}, $extracted,              'padded the extraction time out of the name' );
is( $padded->{suricata_extract_submit}{mime}, 'application_x-dosexec', 'padded the mime out of the name' );
is( $padded->{suricata_extract_submit}{filename}, $std_name,           'padded the filename' );
is( $padded->{suricata_extract_submit}{timestamp},
	'2025-07-27T07:06:30Z', 'padded the extraction time as a UTC timestamp' );
ok(
	!exists( $padded->{suricata_extract_submit}{sha256} ),
	'no sha256 is invented, as the name does not carry the pre send one'
);

# anything actually submitted wins over what the name says
$submit_returns = 2;
$receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => '{"src_ip":"10.9.9.9","suricata_extract_submit":{"slug":"real","sha256":"deadbeef"}}',
	upload    => MockUpload->new( filename => $std_name, content => 'with a json body' ),
	oversized => 0,
);
$padded = decode_json( read_file( $incoming . '/json/' . $std_name ) );
is( $padded->{src_ip},                          '10.9.9.9', 'a submitted .src_ip is not overwritten by the name' );
is( $padded->{suricata_extract_submit}{slug},   'real',     'a submitted slug is not overwritten by the name' );
is( $padded->{suricata_extract_submit}{sha256}, 'deadbeef', 'a submitted sha256 is left alone' );
is( $padded->{dest_ip}, '93.184.216.34',                    'fields the body left out are still padded from the name' );
is( $padded->{suricata_extract_submit}{sha1}, $good_sha1,   'the sha1 the body left out is still padded' );

# a name not in the standard format pads nothing at all
$submit_returns = 3;
$receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => undef,
	upload    => MockUpload->new( filename => 'manual-sample.exe', content => 'manually submitted' ),
	oversized => 0,
);
my $unpadded = decode_json( read_file( $incoming . '/json/manual-sample.exe' ) );
ok( !exists( $unpadded->{suricata_extract_submit} ), 'a non standard name creates no suricata_extract_submit' );
ok( !exists( $unpadded->{src_ip} ),                  'a non standard name pads no flow info' );

# a JSON body that is not a hash is ignored rather than dying
$submit_returns = 4;
$result         = $receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => '[1,2,3]',
	upload    => MockUpload->new( filename => 'array.bin', content => 'array body' ),
	oversized => 0,
);
is( $result->{status}, 200, 'a non hash json body does not blow up the submission' );

#
# only the file bit of the submitted name is used, as it comes straight from the
# multipart headers and may hold path separators
#
my $outside = $incoming . '/outside.txt';
write_file( $outside, "untouched\n" );

$submit_returns = 5;
$result         = $receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => undef,
	upload    => MockUpload->new( filename => '/../outside.txt', content => 'traversal attempt' ),
	oversized => 0,
);
is( $result->{status},   200,           'a name holding a path is reduced to its file bit and still submitted' );
is( read_file($outside), "untouched\n", 'a name holding a path cannot write outside the incoming dir' );
ok( -f $incoming . '/json/outside.txt', 'the JSON lands under json/ named after the file bit' );
my $based = decode_json( read_file( $incoming . '/json/outside.txt' ) );
is( $based->{cape_submit}{name},      'outside.txt',     '.cape_submit.name holds only the file bit' );
is( $based->{cape_submit}{orig_name}, '/../outside.txt', '.cape_submit.orig_name still holds the name as submitted' );

# and a name with nothing usable left after that is refused outright
foreach my $useless ( '..', '/', '../..' ) {
	$submit_returns = 6;
	$result         = $receiver->receive(
		remote_ip => '192.0.2.1',
		apikey    => undef,
		raw_json  => undef,
		upload    => MockUpload->new( filename => $useless, content => 'no usable name' ),
		oversized => 0,
	);
	is( $result->{status}, 400, 'a name of "' . $useless . '" is refused' );
} ## end foreach my $useless ( '..', '/', '../..' )

done_testing();
