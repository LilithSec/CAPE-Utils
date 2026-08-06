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
my $base         = tempdir( CLEANUP => 1 );
my $current_user = getpwuid($>);
my $ini          = $base . '/cape_utils.ini';
write_file( $ini, "base=$base\npoetry=0\ncape_runas=$current_user\n" );

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

#
# running as the wrong user with enable_sudo unset dies
#
my $wrong_ini = $base . '/wrong_user.ini';
write_file( $wrong_ini, "base=$base\npoetry=0\ncape_runas=nope_not_this_user\nenable_sudo=0\n" );
my $wrong_cape = CAPE::Utils->new($wrong_ini);
eval { $wrong_cape->submit( items => [$sample], quiet => 1 ); };
like(
	$@,
	qr/Not being ran as the configured user/,
	'submit dies when not the configured user and enable_sudo is unset'
);

#
# running as the wrong user with enable_sudo set prepends "sudo -u <cape_runas>"
#
my $sudo_ini = $base . '/sudo.ini';
write_file( $sudo_ini, "base=$base\npoetry=0\ncape_runas=nope_not_this_user\nenable_sudo=1\n" );
my $sudo_cape = CAPE::Utils->new($sudo_ini);
$canned_output = qq{Success: File "%s" added as task with ID 5\n};
my @captured_command;
{
	no warnings qw( redefine once );
	local *CAPE::Utils::run = sub {
		my (%run_opts) = @_;
		@captured_command = @{ $run_opts{command} };
		my $submitted_file = $run_opts{command}[-1];
		my $output         = $canned_output;
		$output =~ s/\%s/$submitted_file/g;
		return ( 1, undef, [$output], [$output], [] );
	};
	$sudo_cape->submit( items => [$sample], quiet => 1 );
}
is_deeply(
	[ @captured_command[ 0 .. 2 ] ],
	[ 'sudo', '-u', 'nope_not_this_user' ],
	'submit prepends "sudo -u <cape_runas>" when enable_sudo is set and not the configured user'
);

#
# mime based package selection
#
# the sample is a PDF so that it resolves to a package that is not the
# mime_to_package_default, making it obvious which of the two was used
#
my $pdf = $base . '/sample.pdf';
write_file( $pdf, "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n" );

my $has_libmagic = eval {
	require File::LibMagic;
	File::LibMagic->new;
	1;
};

# returns the value passed to --package for the submission, or undef if it was
# not passed at all
my $submitted_package = sub {
	my ($cape_utils_object) = @_;

	@captured_command = ();
	$canned_output    = qq{Success: File "%s" added as task with ID 9\n};
	{
		no warnings qw( redefine once );
		local *CAPE::Utils::run = sub {
			my (%run_opts) = @_;
			@captured_command = @{ $run_opts{command} };
			my $submitted_file = $run_opts{command}[-1];
			my $output         = $canned_output;
			$output =~ s/\%s/$submitted_file/g;
			return ( 1, undef, [$output], [$output], [] );
		};
		$cape_utils_object->submit( items => [$pdf], quiet => 1, @_[ 1 .. $#_ ] );
	}

	my $found;
	for my $index ( 0 .. $#captured_command ) {
		if ( $captured_command[$index] eq '--package' ) {
			$found = $captured_command[ $index + 1 ];
		}
	}

	return $found;
}; ## end $submitted_package = sub

is( $submitted_package->($cape_util), undef, 'no --package is passed when mime_to_package is off' );

is( $submitted_package->( $cape_util, package => 'zip' ), 'zip', 'a explicitly passed package is used' );

is( $submitted_package->( $cape_util, package => 'auto' ), undef, 'a package of auto means no --package is passed' );

SKIP: {
	skip( 'File::LibMagic is not usable', 5 ) if !$has_libmagic;

	is( $submitted_package->( $cape_util, mime_to_package => 1 ),
		'pdf', 'the package is worked out from the mime type when mime_to_package is set' );

	my $mime_ini = $base . '/mime.ini';
	write_file( $mime_ini, "base=$base\npoetry=0\ncape_runas=$current_user\nmime_to_package=1\n" );
	my $mime_cape = CAPE::Utils->new($mime_ini);

	is( $submitted_package->($mime_cape), 'pdf', 'mime_to_package may be enabled via the config' );

	is( $submitted_package->( $mime_cape, mime_to_package => 0 ),
		undef, 'a passed mime_to_package of 0 overrides the config' );

	is( $submitted_package->( $mime_cape, package => 'zip' ),
		'zip', 'a explicitly passed package wins over mime based selection' );

	is( $submitted_package->( $mime_cape, package => 'auto' ),
		undef, 'a package of auto wins over mime based selection' );
} ## end SKIP:

#
# dry runs, which submit nothing and may be ran by any user
#
SKIP: {
	skip( 'File::LibMagic is not usable', 7 ) if !$has_libmagic;

	my $dry_run_results;
	{
		no warnings qw( redefine once );
		local *CAPE::Utils::run = sub {
			fail('submit ran a command during a dry run');
			return ( 1, undef, [''], [''], [] );
		};
		$dry_run_results = $wrong_cape->submit(
			items           => [$pdf],
			mime_to_package => 1,
			dry_run         => 1,
			quiet           => 1,
		);
	}

	is( $dry_run_results->{$pdf}{mime},    'application/pdf', 'a dry run reports the detected mime' );
	is( $dry_run_results->{$pdf}{package}, 'pdf',             'a dry run reports the package it would use' );
	is_deeply(
		[ @{ $dry_run_results->{$pdf}{command} }[ -3 .. -1 ] ],
		[ '--package', 'pdf', $pdf ],
		'a dry run reports the command it would run'
	);
	is( $dry_run_results->{$pdf}{command}[0],
		'python3', 'a dry run skips the cape_runas handling, so it may be ran by any user' );

	#
	# a dry run with a explicitly passed package reports that package and not the
	# mime based one
	#
	{
		no warnings qw( redefine once );
		local *CAPE::Utils::run = sub {
			fail('submit ran a command during a dry run');
			return ( 1, undef, [''], [''], [] );
		};
		$dry_run_results = $wrong_cape->submit(
			items   => [$pdf],
			package => 'zip',
			dry_run => 1,
			quiet   => 1,
		);
	}

	is( $dry_run_results->{$pdf}{package}, 'zip', 'a dry run reports a explicitly passed package' );
	is_deeply(
		[ @{ $dry_run_results->{$pdf}{command} }[ -3 .. -1 ] ],
		[ '--package', 'zip', $pdf ],
		'a explicitly passed package lands in the command of a dry run'
	);
	is( $dry_run_results->{$pdf}{mime},
		'application/pdf', 'a dry run reports the detected mime even with mime based selection off' );
} ## end SKIP:

#
# the random option, which shuffles the order the items are submitted in
#
my $random_dir = $base . '/random';
mkdir($random_dir);
foreach my $item_number ( 1 .. 20 ) {
	write_file( $random_dir . '/sample' . sprintf( '%02d', $item_number ) . '.bin', 'sample' . $item_number );
}

# submits the whole dir and hands back the order the items reached submit.py in
my $submit_order_for = sub {
	my (%submit_opts) = @_;

	my @submitted_order;
	{
		no warnings qw( redefine once );
		local *CAPE::Utils::run = sub {
			my (%run_opts) = @_;
			push( @submitted_order, $run_opts{command}[-1] );
			return ( 1, undef, [''], [''], [] );
		};
		$cape_util->submit( items => [$random_dir], quiet => 1, %submit_opts );
	}

	return \@submitted_order;
}; ## end $submit_order_for = sub

my $unshuffled = $submit_order_for->( random => 0 );
is( scalar( @{$unshuffled} ), 20, 'every item in a submitted dir is submitted' );
is_deeply( $submit_order_for->( random => 0 ), $unshuffled, 'random => 0 submits in a stable order' );

is_deeply(
	[ sort @{ $submit_order_for->( random => 1 ) } ],
	[ sort @{$unshuffled} ],
	'random => 1 submits the same set of items, none lost or repeated'
);

# 20 items shuffling back into the same order is possible but not something that
# will ever be seen, so a handful of tries is plenty to show it is shuffling
my $shuffles_by_default = 0;
foreach ( 1 .. 5 ) {
	if ( join( ',', @{ $submit_order_for->() } ) ne join( ',', @{$unshuffled} ) ) {
		$shuffles_by_default = 1;
		last;
	}
}
ok( $shuffles_by_default, 'the order is shuffled by default' );

done_testing();
