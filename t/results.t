#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir );
use File::Path  qw( make_path );
use File::Slurp qw( read_file write_file );
use JSON        qw( decode_json );

use_ok('CAPE::Utils::Nergal') || print "Bail out!\n";

# keep syslog quiet during the run
no warnings qw( redefine once );
local *CAPE::Utils::LogDrek::openlog  = sub { };
local *CAPE::Utils::LogDrek::closelog = sub { };
local *CAPE::Utils::LogDrek::syslog   = sub { };
use warnings qw( redefine once );

#
# build a fake CAPEv2 analyses tree for task 33
#
my $base     = tempdir( CLEANUP => 1 );
my $task_dir = $base . '/storage/analyses/33';
make_path( $task_dir . '/reports' );
make_path( $task_dir . '/shots' );

write_file( $task_dir . '/reports/lite.json',   '{"lite":true}' );
write_file( $task_dir . '/reports/report.json', '{"report":true}' );
write_file( $task_dir . '/shots/0001.jpg',      'not really a jpg' );
write_file( $task_dir . '/shots/0002.jpg',      'also not a jpg' );

# report.html and summary-report.html are intentionally absent

# ini: results gated to 192.0.2.0/24 via ip auth
my $ini = $base . '/cape_utils.ini';
write_file( $ini, "base=$base\nresults_auth=ip\nresults_subnets=192.0.2.0/24\n" );

my $allowed = '192.0.2.10';
my $denied  = '198.51.100.1';

my $nergal = CAPE::Utils::Nergal->new( ini => $ini );

#
# results_list
#
my $list = $nergal->results_list( task_id => 33, remote_ip => $allowed, apikey => undef );
is( $list->{status}, 200, 'results_list returns 200 for an allowed IP' );
is_deeply(
	decode_json( $list->{body} ),
	[ 'reports/lite.json', 'reports/report.json', 'shots/0001.jpg', 'shots/0002.jpg' ],
	'results_list reports only the files that exist, shots enumerated and sorted'
);

my $list_denied = $nergal->results_list( task_id => 33, remote_ip => $denied, apikey => undef );
is( $list_denied->{status}, 403, 'results_list denies an out-of-subnet IP' );

my $list_bad = $nergal->results_list( task_id => 'abc', remote_ip => $allowed, apikey => undef );
is( $list_bad->{status}, 400, 'results_list rejects a non numeric task ID' );

my $list_missing = $nergal->results_list( task_id => 999, remote_ip => $allowed, apikey => undef );
is( $list_missing->{status}, 404, 'results_list 404s for a task with no analysis dir' );

#
# results_fetch
#
my $fetch = $nergal->results_fetch( task_id => 33, path => 'reports/lite.json', remote_ip => $allowed );
is( $fetch->{status},       200,                'results_fetch returns 200 for an allowed file' );
is( $fetch->{content_type}, 'application/json', 'json served as application/json' );
ok( defined( $fetch->{path} ) && -f $fetch->{path}, 'results_fetch resolves to a real file' );
is( read_file( $fetch->{path} ), '{"lite":true}', 'the resolved file is the right one' );

my $shot = $nergal->results_fetch( task_id => 33, path => 'shots/0001.jpg', remote_ip => $allowed );
is( $shot->{content_type}, 'image/jpeg', 'jpg served as image/jpeg' );

# allowed by the whitelist but the file does not exist
my $absent = $nergal->results_fetch( task_id => 33, path => 'reports/report.html', remote_ip => $allowed );
is( $absent->{status}, 404, 'results_fetch 404s for an allowed-but-missing file' );

# not on the whitelist at all
my $notlisted = $nergal->results_fetch( task_id => 33, path => 'reports/secret.json', remote_ip => $allowed );
is( $notlisted->{status}, 404, 'results_fetch 404s for a file outside the allowed set' );

# path traversal attempt
my $traversal = $nergal->results_fetch( task_id => 33, path => '../../../../etc/passwd', remote_ip => $allowed );
is( $traversal->{status}, 404, 'results_fetch 404s on a traversal attempt' );
ok( !defined( $traversal->{path} ), 'traversal attempt yields no path to serve' );

# auth still applies to fetch
my $fetch_denied = $nergal->results_fetch( task_id => 33, path => 'reports/lite.json', remote_ip => $denied );
is( $fetch_denied->{status}, 403, 'results_fetch denies an out-of-subnet IP' );

done_testing();
