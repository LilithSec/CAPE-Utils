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
my @submit_calls;
no warnings qw( redefine once );
local *CAPE::Utils::check_remote = sub { return 1; };
local *CAPE::Utils::submit       = sub {
	my ( $self, %o ) = @_;
	push( @submit_calls, $o{items}[0] );
	return { $o{items}[0] => $submit_returns };
};
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

# the sections read for logging are never created by reading them, including on
# the http logging branch, which is the one that touches the http section most
$submit_returns = 30;
$receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => '{"app_proto":"http"}',
	upload    => MockUpload->new( filename => 'nosections.bin', content => 'no sections at all' ),
	oversized => 0,
);
my $nosections = decode_json( read_file( $incoming . '/json/nosections.bin' ) );
foreach my $section (qw( http suricata_extract_submit lilith_cape_submit )) {
	ok( !exists( $nosections->{$section} ), 'reading for logging creates no empty ' . $section . ' section' );
}
ok( !exists( $nosections->{det_sub_type} ), 'no det_sub_type is written out where there is no http method' );

# the http method is what det_sub_type is taken from
$submit_returns = 32;
$receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => '{"app_proto":"http","http":{"http_method":"get"}}',
	upload    => MockUpload->new( filename => 'withmethod.bin', content => 'has a method' ),
	oversized => 0,
);
my $withmethod = decode_json( read_file( $incoming . '/json/withmethod.bin' ) );
is( $withmethod->{det_sub_type}, 'get', 'det_sub_type is taken from the http method' );

# and a submitted one is left be where there is no method to take it from
$submit_returns = 33;
$receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => '{"det_sub_type":"manual"}',
	upload    => MockUpload->new( filename => 'subtype.bin', content => 'submitted type' ),
	oversized => 0,
);
my $subtype = decode_json( read_file( $incoming . '/json/subtype.bin' ) );
is( $subtype->{det_sub_type}, 'manual', 'a submitted det_sub_type is not clobbered' );

# and one submitted as something other than a hash is left as submitted rather
# than being replaced by the empty hash used in its place for logging
$submit_returns = 31;
$receiver->receive(
	remote_ip => '192.0.2.1',
	apikey    => undef,
	raw_json  => '{"app_proto":"http","http":"not a hash","lilith_cape_submit":[1,2]}',
	upload    => MockUpload->new( filename => 'oddsections.bin', content => 'odd sections' ),
	oversized => 0,
);
my $oddsections = decode_json( read_file( $incoming . '/json/oddsections.bin' ) );
is( $oddsections->{http}, 'not a hash', 'a non hash http section is left as submitted' );
is_deeply( $oddsections->{lilith_cape_submit}, [ 1, 2 ], 'a non hash lilith_cape_submit section is left as submitted' );

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

#
# submission gate
#
my $gate_dir = $incoming . '/gate';
mkdir($gate_dir);

# what is sitting in tmp before any of this, as the early returns for a name with
# no usable file bit in it leave their tempfile behind, which File::Temp only
# cleans up at exit
my %tmp_before     = map { $_ => 1 } glob( $incoming . '/tmp/*' );
my $gate_env_file  = $gate_dir . '/env';
my $gate_json_copy = $gate_dir . '/json';
my $gate_ini       = $incoming . '/gate.ini';
my $gate_receiver  = CAPE::Utils::Nergal->new( ini => $gate_ini );

# a gate that records the enviroment it was handed, says something on both
# stdout and stderr, and exits with the passed code
sub gate_script {
	my ($exit_code) = @_;

	my $path = $gate_dir . '/gate-' . $exit_code;
	write_file( $path,
			  "#!/bin/sh\n"
			. "env | grep '^NERGAL_' | sort > "
			. $gate_env_file . "\n"
			. "if [ -f \"\$NERGAL_FILE\" ]; then echo file-exists >> "
			. $gate_env_file
			. "; fi\n"
			. "if [ -n \"\$NERGAL_JSON\" ]; then cat \"\$NERGAL_JSON\" > "
			. $gate_json_copy
			. "; fi\n"
			. "echo gate-said-this\n"
			. "echo gate-warned-this >&2\n" . "exit "
			. $exit_code
			. "\n" );
	chmod( 0755, $path );

	return $path;
} ## end sub gate_script

# what the gate was handed, as a hash of the NERGAL_ vars it was ran with
sub gate_env {
	my %env;
	foreach my $line ( split( /\n/, read_file($gate_env_file) ) ) {
		my ( $var, $value ) = split( /=/, $line, 2 );
		$env{$var} = $value;
	}

	return \%env;
}

# put a gate in place and run a submission through it
sub run_gated {
	my ( $gate_command, $name, %opts ) = @_;

	my $config = "incoming=$incoming\nsubmission_gate=$gate_command\n";
	if ( defined( $opts{timeout} ) ) {
		$config = $config . "submission_gate_timeout=$opts{timeout}\n";
	}
	write_file( $gate_ini, $config );

	@submit_calls   = ();
	$submit_returns = 42;

	return $gate_receiver->receive(
		remote_ip => '192.0.2.1',
		apikey    => undef,
		raw_json  => $opts{raw_json},
		upload    => MockUpload->new( filename => $name, content => $name . ' content' ),
		oversized => 0,
	);
} ## end sub run_gated

# 0, accept it, which is business as usual
$result = run_gated( gate_script(0), 'gate0.bin', raw_json => '{}' );
is( $result->{status},     200,                         'a gate exiting 0 accepts the submission' );
is( $result->{body},       "Submitted as task ID 42\n", 'a gate exiting 0 replies with the task ID' );
is( scalar(@submit_calls), 1,                           'a gate exiting 0 submits it' );
ok( -f $incoming . '/json/gate0.bin', 'a gate exiting 0 saves the JSON' );
my $gate0_json = decode_json( read_file( $incoming . '/json/gate0.bin' ) );
is( $gate0_json->{cape_submit}{gate_results}{exit},   0,                    'gate_results holds the exit' );
is( $gate0_json->{cape_submit}{gate_results}{stdout}, "gate-said-this\n",   'gate_results holds the stdout' );
is( $gate0_json->{cape_submit}{gate_results}{stderr}, "gate-warned-this\n", 'gate_results holds the stderr' );

# 1, accept and save it, but do not submit it
$result = run_gated( gate_script(1), 'gate1.bin', raw_json => '{}' );
is( $result->{status},     200,          'a gate exiting 1 accepts the submission' );
is( $result->{body},       "Accepted\n", 'a gate exiting 1 replies with an accepted' );
is( scalar(@submit_calls), 0,            'a gate exiting 1 does not submit it' );
ok( -f $incoming . '/json/gate1.bin',           'a gate exiting 1 still saves the JSON' );
ok( -l $incoming . '/name_to_sha256/gate1.bin', 'a gate exiting 1 still saves the sample' );
my $gate1_json = decode_json( read_file( $incoming . '/json/gate1.bin' ) );
ok( !exists( $gate1_json->{cape_submit}{task} ), 'a gate exiting 1 records no task' );
is( $gate1_json->{cape_submit}{gate_results}{exit}, 1, 'gate_results is recorded for an exit of 1 as well' );

# 2, accept it, but keep nothing
$result = run_gated( gate_script(2), 'gate2.bin', raw_json => '{}' );
is( $result->{status},     200,          'a gate exiting 2 accepts the submission' );
is( $result->{body},       "Accepted\n", 'a gate exiting 2 replies with an accepted' );
is( scalar(@submit_calls), 0,            'a gate exiting 2 does not submit it' );
ok( !-e $incoming . '/json/gate2.bin',           'a gate exiting 2 saves no JSON' );
ok( !-e $incoming . '/name_to_sha256/gate2.bin', 'a gate exiting 2 saves no sample' );

# 3, 4, and 5, the denials
my %denials = ( 3 => 444, 4 => 445, 5 => 403 );
foreach my $exit_code ( sort( keys(%denials) ) ) {
	my $name = 'gate' . $exit_code . '.bin';
	$result = run_gated( gate_script($exit_code), $name, raw_json => '{}' );
	is( $result->{status}, $denials{$exit_code},
		'a gate exiting ' . $exit_code . ' denies with a ' . $denials{$exit_code} );
	is( $result->{body},       "Denied\n", 'a gate exiting ' . $exit_code . ' replies with a denied' );
	is( scalar(@submit_calls), 0,          'a gate exiting ' . $exit_code . ' does not submit it' );
	ok( !-e $incoming . '/json/' . $name, 'a gate exiting ' . $exit_code . ' keeps nothing' );
}

# a gate that is broken rather than making a call is an error, not a verdict
$result = run_gated( gate_script(9), 'gate9.bin', raw_json => '{}' );
is( $result->{status}, 400,                            'an unknown exit is an error' );
is( $result->{body},   "Error... please see syslog\n", 'an unknown exit replies with the standard error' );
ok( !-e $incoming . '/json/gate9.bin', 'an unknown exit keeps nothing' );

$result = run_gated( $gate_dir . '/does-not-exist', 'gatemissing.bin', raw_json => '{}' );
is( $result->{status}, 400, 'a gate that cannot be ran is an error rather than an exit of 2' );
ok( !-e $incoming . '/json/gatemissing.bin', 'a gate that cannot be ran keeps nothing' );

# a gate that hangs is not allowed to hang the submission with it
$result = run_gated( '/bin/sleep 30', 'gateslow.bin', raw_json => '{}', timeout => 1 );
is( $result->{status}, 400, 'a gate that times out is an error rather than an exit of 0' );
ok( !-e $incoming . '/json/gateslow.bin', 'a gate that times out keeps nothing' );

# what the gate is told, for a submission padded from its name and holding no body
$result = run_gated( gate_script(0), $std_name );
my $env = gate_env();
is( $env->{NERGAL_SLUG},      'acme',                  'the gate is told the slug' );
is( $env->{NERGAL_MIME},      'application_x-dosexec', 'the gate is told the mime' );
is( $env->{NERGAL_SRC_IP},    '192.168.1.5',           'the gate is told the source IP' );
is( $env->{NERGAL_SRC_PORT},  49152,                   'the gate is told the source port' );
is( $env->{NERGAL_DEST_IP},   '93.184.216.34',         'the gate is told the dest IP' );
is( $env->{NERGAL_DEST_PORT}, 80,                      'the gate is told the dest port' );
is( $env->{NERGAL_PROTO},     'TCP',                   'the gate is told the proto' );
is(
	$env->{NERGAL_SHA256},
	$receiver->checksums( $incoming . '/name_to_sha256/' . $std_name )->{sha256},
	'the gate is told the sha256'
);
ok( exists( $env->{NERGAL_SHA1} ),       'the gate is told the sha1' );
ok( exists( $env->{NERGAL_MD5} ),        'the gate is told the md5' );
ok( exists( $env->{'file-exists'} ),     'the file is there to be looked at while the gate is running' );
ok( !exists( $env->{NERGAL_JSON} ),      'no NERGAL_JSON where no body was submitted' );
ok( !exists( $env->{NERGAL_APP_PROTO} ), 'no NERGAL_APP_PROTO where there is no app proto' );

# and for one that submitted a body
unlink($gate_json_copy);
$result = run_gated( gate_script(0), 'gatejson.bin', raw_json => '{"app_proto":"http","src_ip":"10.0.0.1"}' );
$env    = gate_env();
is( $env->{NERGAL_APP_PROTO},   'http',     'the gate is told the app proto' );
is( $env->{NERGAL_SRC_IP},      '10.0.0.1', 'the gate is told the submitted source IP' );
is( read_file($gate_json_copy), '{"app_proto":"http","src_ip":"10.0.0.1"}', 'NERGAL_JSON holds the body as submitted' );
ok( !-e $env->{NERGAL_JSON}, 'the JSON handed to the gate is cleaned up after' );

# neither the samples nor the JSONs handed to the gate are left behind in tmp by
# any of the above, denied or otherwise
my @tmp_leftovers = grep { !$tmp_before{$_} } glob( $incoming . '/tmp/*' );
is_deeply( \@tmp_leftovers, [], 'the submission gate leaves nothing behind in tmp' );

# and with no gate configured nothing about a submission changes
$result = run_gated( '', 'gatenone.bin', raw_json => '{}' );
is( $result->{status}, 200,                         'an empty submission_gate leaves submissions alone' );
is( $result->{body},   "Submitted as task ID 42\n", 'an empty submission_gate still replies with the task ID' );
my $ungated_json = decode_json( read_file( $incoming . '/json/gatenone.bin' ) );
ok( !exists( $ungated_json->{cape_submit}{gate_results} ), 'no gate_results where there is no gate' );

done_testing();
