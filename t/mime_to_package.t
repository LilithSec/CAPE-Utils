#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir );
use File::Slurp qw( write_file );

use_ok('CAPE::Utils') || print "Bail out!\n";

my $dir = tempdir( CLEANUP => 1 );

#
# a config with no mime_packages section at all, so everything is the shipped defaults
#
my $default_ini = $dir . '/defaults.ini';
write_file( $default_ini, "base=$dir\npoetry=0\n" );
my $cape_util = CAPE::Utils->new($default_ini);

is( $cape_util->{config}{_}{mime_to_package},         0,     'mime_to_package defaults to 0' );
is( $cape_util->{config}{_}{mime_to_package_default}, 'exe', 'mime_to_package_default defaults to exe' );
is( $cape_util->{config}{_}{dll_check},               1,     'dll_check defaults to 1' );

is( $cape_util->mime_to_package( mime => 'application/pdf' ), 'pdf', 'a mapped mime returns its package' );
is( $cape_util->mime_to_package( mime => 'application/x-msi' ),
	'msi', 'x-msi maps to msi, which is the whole reason libmagic is used over the shared mime info db' );
is( $cape_util->mime_to_package( mime => 'application/vnd.microsoft.portable-executable' ), 'exe', 'a PE maps to exe' );

#
# unmapped mime types fall through to mime_to_package_default
#
is( $cape_util->mime_to_package( mime => 'application/x-not-a-real-mime' ),
	'exe', 'a unmapped mime falls through to mime_to_package_default' );
is( $cape_util->mime_to_package( mime => undef ), 'exe', 'a undef mime falls through to mime_to_package_default' );

#
# 'auto' means let CAPE decide, so no package
#
is( $cape_util->mime_to_package( mime => 'application/x-ole-storage' ),
	undef, 'a mime mapped to auto returns undef instead of the default' );
is( $cape_util->mime_to_package( mime => 'text/plain' ), undef, 'text/plain is mapped to auto' );

#
# the mime is normalized before the lookup
#
is( $cape_util->mime_to_package( mime => 'APPLICATION/PDF' ),   'pdf', 'the mime lookup is case insensitive' );
is( $cape_util->mime_to_package( mime => ' application/pdf ' ), 'pdf', 'surrounding whitespace is ignored' );
is( $cape_util->mime_to_package( mime => 'text/rtf; charset=us-ascii' ),
	'rtf', 'any mime parameters are dropped before the lookup' );

#
# the DLL check, as libmagic gives both a EXE and a DLL the same mime type
#
is(
	$cape_util->mime_to_package(
		mime        => 'application/vnd.microsoft.portable-executable',
		description => 'PE32 executable (DLL) (GUI) Intel 80386, for MS Windows',
	),
	'dll',
	'a PE described as a DLL resolves to the dll package'
);
is(
	$cape_util->mime_to_package(
		mime        => 'application/vnd.microsoft.portable-executable',
		description => 'PE32 executable (GUI) Intel 80386, for MS Windows',
	),
	'exe',
	'a PE not described as a DLL stays exe'
);
is(
	$cape_util->mime_to_package(
		mime        => 'application/pdf',
		description => 'a lying description holding (DLL) in it',
	),
	'pdf',
	'the DLL check only applies to items resolving to the exe package'
);

#
# config handling
#
my $override_ini = $dir . '/override.ini';
write_file( $override_ini,
		  "base=$dir\npoetry=0\ndll_check=0\nmime_to_package_default=auto\n"
		. "[mime_packages]\napplication/pdf=doc\napplication/zip=\napplication/x-ole-storage=xls\n" );
$cape_util = CAPE::Utils->new($override_ini);

is( $cape_util->mime_to_package( mime => 'application/pdf' ), 'doc', 'a config mapping overrides a shipped one' );
is( $cape_util->mime_to_package( mime => 'application/x-msi' ),
	'msi', 'the shipped mappings survive a partial mime_packages section' );
is( $cape_util->mime_to_package( mime => 'application/x-ole-storage' ),
	'xls', 'a shipped auto mapping may be overridden with a package' );
is( $cape_util->mime_to_package( mime => 'application/x-not-a-real-mime' ),
	undef, 'a mime_to_package_default of auto means no package for unmapped mimes' );
is( $cape_util->mime_to_package( mime => 'application/zip' ),
	undef, 'a emptied mapping falls through to mime_to_package_default' );
is(
	$cape_util->mime_to_package(
		mime        => 'application/vnd.microsoft.portable-executable',
		description => 'PE32 executable (DLL) (GUI) Intel 80386, for MS Windows',
	),
	'exe',
	'dll_check=0 leaves a DLL as exe'
);

my $empty_default_ini = $dir . '/empty_default.ini';
write_file( $empty_default_ini, "base=$dir\npoetry=0\nmime_to_package_default=\n" );
$cape_util = CAPE::Utils->new($empty_default_ini);
is( $cape_util->mime_to_package( mime => 'application/x-not-a-real-mime' ),
	undef, 'a empty mime_to_package_default means no package for unmapped mimes' );

#
# detection, which needs File::LibMagic and its magic db
#
$cape_util = CAPE::Utils->new($default_ini);

my $has_libmagic = eval {
	require File::LibMagic;
	File::LibMagic->new;
	1;
};

SKIP: {
	skip( 'File::LibMagic is not usable', 6 ) if !$has_libmagic;

	my $pdf = $dir . '/sample.pdf';
	write_file( $pdf, "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n" );

	my $detected = $cape_util->mime_detect( file => $pdf );
	is( $detected->{mime}, 'application/pdf', 'mime_detect finds the mime type of a PDF' );
	ok( defined( $detected->{description} ), 'mime_detect returns a description as well' );

	is( $cape_util->mime_to_package( file => $pdf ), 'pdf', 'mime_to_package detects the mime when given a file' );

	# items are commonly handed in via a symlink pointing at the real file, and
	# without libmagic set to follow those they detect as 'inode/symlink', which
	# then falls through to the mime_to_package_default
	my $pdf_link = $dir . '/sample-link.pdf';
	symlink( $pdf, $pdf_link );
	is( $cape_util->mime_detect( file => $pdf_link )->{mime}, 'application/pdf', 'mime_detect follows a symlink' );
	is( $cape_util->mime_to_package( file => $pdf_link ),     'pdf',             'mime_to_package follows a symlink' );

	eval { $cape_util->mime_detect( file => $dir . '/does-not-exist' ) };
	ok( $@, 'mime_detect dies on a file that does not exist' );
} ## end SKIP:

eval { $cape_util->mime_detect() };
ok( $@, 'mime_detect dies when passed no file' );

#
# the settings as used by the mime_to_packages command
#
my $settings = $cape_util->mime_packages;
is( $settings->{mime_to_package},                  0,     'mime_packages reports mime_to_package' );
is( $settings->{mime_to_package_default},          'exe', 'mime_packages reports mime_to_package_default' );
is( $settings->{dll_check},                        1,     'mime_packages reports dll_check' );
is( $settings->{mime_packages}{'application/pdf'}, 'pdf', 'mime_packages reports the mappings' );

$settings->{mime_packages}{'application/pdf'} = 'nope';
is( $cape_util->mime_packages->{mime_packages}{'application/pdf'},
	'pdf', 'the mappings are copied out, so a caller can not reach back into the config' );

my $table = $cape_util->mime_packages_table;
like( $table, qr/^mime_to_package=0$/m,              'the table includes the mime_to_package setting' );
like( $table, qr/^mime_to_package_default=exe$/m,    'the table includes the mime_to_package_default setting' );
like( $table, qr/^dll_check=1$/m,                    'the table includes the dll_check setting' );
like( $table, qr/application\/pdf\s+pdf/,            'the table includes a mapped mime type' );
like( $table, qr/application\/x-ole-storage\s+auto/, 'a mime type mapped to auto shows as auto in the table' );

#
# a emptied mapping shows as what it resolves to and not as a empty value
#
my $emptied_ini = $dir . '/emptied.ini';
write_file( $emptied_ini, "base=$dir\npoetry=0\n[mime_packages]\napplication/pdf=\n" );
$table = CAPE::Utils->new($emptied_ini)->mime_packages_table;
like( $table, qr/application\/pdf\s+exe/, 'a emptied mapping shows as the mime_to_package_default in the table' );

#
# INI output, which unlike the table uses the raw config values
#
my $ini = $cape_util->mime_packages_ini;
like( $ini, qr/^mime_to_package=0$/m,               'the INI includes the settings' );
like( $ini, qr/^\[mime_packages\]$/m,               'the INI includes the mime_packages section header' );
like( $ini, qr/^application\/pdf=pdf$/m,            'the INI includes a mapped mime type' );
like( $ini, qr/^application\/x-ole-storage=auto$/m, 'the INI writes a auto mapping back out as auto' );

$ini = CAPE::Utils->new($emptied_ini)->mime_packages_ini;
like( $ini, qr/^application\/pdf=$/m, 'the INI writes a emptied mapping back out empty rather than resolved' );

#
# diff, which limits the above to what differs from the shipped defaults
#
$settings = $cape_util->mime_packages( diff => 1 );
is_deeply( $settings, { mime_packages => {} }, 'a unmodified config has no differences from the defaults' );
is( $cape_util->mime_packages_ini( diff => 1 ), '', 'the diff INI of a unmodified config is empty' );

my $diff_ini_file = $dir . '/diff.ini';
write_file( $diff_ini_file,
	"base=$dir\npoetry=0\ndll_check=0\n[mime_packages]\napplication/pdf=doc\napplication/x-fake=exe\n" );
my $diff_cape = CAPE::Utils->new($diff_ini_file);

$settings = $diff_cape->mime_packages( diff => 1 );
is_deeply(
	$settings,
	{
		dll_check     => 0,
		mime_packages => {
			'application/pdf'    => 'doc',
			'application/x-fake' => 'exe',
		},
	},
	'diff reports only the changed setting, the changed mapping, and the added mapping'
);

ok( !exists( $settings->{mime_to_package} ), 'a setting matching its default is left out of a diff' );

$ini = $diff_cape->mime_packages_ini( diff => 1 );
is(
	$ini,
	"dll_check=0\n\n[mime_packages]\napplication/pdf=doc\napplication/x-fake=exe\n",
	'the diff INI is a minimal config fragment'
);

$table = $diff_cape->mime_packages_table( diff => 1 );
like( $table, qr/^dll_check=0$/m, 'the diff table includes the changed setting' );
unlike( $table, qr/^mime_to_package=/m, 'the diff table leaves out unchanged settings' );
like( $table, qr/application\/pdf\s+doc/, 'the diff table includes the changed mapping' );
unlike( $table, qr/application\/x-msi/, 'the diff table leaves out unchanged mappings' );

done_testing;
