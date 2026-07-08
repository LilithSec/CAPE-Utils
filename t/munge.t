#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir );
use File::Slurp qw( read_file write_file );
use JSON        qw( decode_json encode_json );

use CAPE::Utils;

my $tempdir = tempdir( CLEANUP => 1 );

my $cape = CAPE::Utils->new( $tempdir . '/does_not_exist.ini' );

#
# error paths
#
eval { $cape->munge; };
like( $@, qr/No\ file\ specified/, 'dies if no file is specified' );

eval { $cape->munge( file => $tempdir . '/does_not_exist.json' ); };
like( $@, qr/is\ not\ a\ file/, 'dies if the file does not exist' );

my $not_json = $tempdir . '/not_json.json';
write_file( $not_json, 'not actually JSON' );
eval { $cape->munge( file => $not_json ); };
like( $@, qr/Failed\ to\ parse/, 'dies if the file is not parsable as JSON' );

#
# no munge sections... should be a no-op other than creating the pre-munge file
#
my $report_file = $tempdir . '/report.json';
my $report_json = encode_json( { malscore => 0, signatures => [] } );
write_file( $report_file, $report_json );
my $returned = $cape->munge( file => $report_file );
is( $returned, 1, 'munge with no munge sections returns 1' );
my $pre_munge_file = $report_file . '.pre-cape_utils_munge';
ok( -f $pre_munge_file, 'pre-munge file created' );
is( read_file($pre_munge_file), $report_json, 'pre-munge file matches the original report' );
is( read_file($report_file),    $report_json, 'report unchanged when there are no munge sections' );

#
# a actual munge via check/munge scripts specified in the config
#
my $check_file = $tempdir . '/test_check';
write_file( $check_file, '$munge_it = 1;' . "\n" );
my $munge_file = $tempdir . '/test_munge';
write_file( $munge_file, '$report->{munged_by_test} = 1; $changed = 1;' . "\n" );
my $ini = $tempdir . '/cape_utils.ini';
write_file( $ini, "[munge_test]\ncheck=" . $check_file . "\nmunge=" . $munge_file . "\n" );

my $cape2 = CAPE::Utils->new($ini);

my $munged_report_file = $tempdir . '/munged_report.json';
my $munged_report_json = encode_json(
	{
		malscore   => 0,
		signatures => [ { severity => 5, weight => 1, confidence => 100 } ],
	}
);
write_file( $munged_report_file, $munged_report_json );
$returned = $cape2->munge( file => $munged_report_file );
is( $returned, 1, 'munge with a munge section returns 1' );

my $munged = decode_json( read_file($munged_report_file) );
is( $munged->{munged_by_test}, 1,   'munge script was ran and changed the report' );
is( $munged->{malscore},       0.5, 'malscore recomputed post munge' );

my $pre_munge = decode_json( read_file( $munged_report_file . '.pre-cape_utils_munge' ) );
ok( !defined( $pre_munge->{munged_by_test} ), 'pre-munge file does not contain the munge changes' );

#
# re-munging should warn about the pre-munge file and not overwrite it
#
my @warnings;
{
	local $SIG{__WARN__} = sub { push( @warnings, $_[0] ); };
	$cape2->munge( file => $munged_report_file );
}
ok( ( grep( /already\ exists/, @warnings ) ), 'warns when the pre-munge file already exists' );
$pre_munge = decode_json( read_file( $munged_report_file . '.pre-cape_utils_munge' ) );
ok( !defined( $pre_munge->{munged_by_test} ), 'pre-munge file not overwritten on re-munge' );

done_testing;
