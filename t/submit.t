#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir );
use File::Slurp qw( write_file );

use_ok('CAPE::Utils') || print "Bail out!\n";

#
# build a throwaway base dir + config pointing at it so chdir in submit works
#
my $base = tempdir( CLEANUP => 1 );
my $ini  = $base . '/cape_utils.ini';
write_file( $ini, "base=$base\npoetry=0\n" );

my $sample = $base . '/sample.bin';
write_file( $sample, 'sample' );

#
# mock the submit.py invocation... emits whatever output the test sets, with
# the submitted file path filled in for any %s
#
my $canned_output;
no warnings qw( redefine once );
local *CAPE::Utils::run = sub {
	my (%run_opts)     = @_;
	my $submitted_file = $run_opts{command}[-1];
	my $output         = $canned_output;
	$output =~ s/\%s/$submitted_file/g;
	return ( 1, undef, [$output], [$output], [] );
};
use warnings qw( redefine once );

my $cape_util = CAPE::Utils->new($ini);

#
# single task ID form
#
$canned_output = qq{Success: File "%s" added as task with ID 123\n};
my $results = $cape_util->submit( items => [$sample], quiet => 1 );
is_deeply( $results, { $sample => '123' }, 'single task ID line parsed' );

#
# multiple task IDs form, as emitted by newer CAPE when a submission fans out
#
$canned_output = qq{Success: File "%s" added as task with IDs [307616, 307617, 307618]\n};
$results       = $cape_util->submit( items => [$sample], quiet => 1 );
is_deeply( $results, { $sample => '307616,307617,307618' }, 'multiple task IDs line parsed to a comma joined value' );

#
# ANSI color codes are stripped before parsing
#
$canned_output = qq{\e[1mSuccess: File "%s" added as task with IDs [1, 2]\e[0m\n};
$results       = $cape_util->submit( items => [$sample], quiet => 1 );
is_deeply( $results, { $sample => '1,2' }, 'colored multiple task IDs line parsed' );

#
# a failure line results in nothing added
#
$canned_output = qq{Error: adding task to database\n};
$results       = $cape_util->submit( items => [$sample], quiet => 1 );
is_deeply( $results, {}, 'non-success output results in an empty hashref' );

done_testing();
