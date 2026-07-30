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
	skip( 'File::LibMagic is not usable', 4 ) if !$has_libmagic;

	my $pdf = $dir . '/sample.pdf';
	write_file( $pdf, "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n" );

	my $detected = $cape_util->mime_detect( file => $pdf );
	is( $detected->{mime}, 'application/pdf', 'mime_detect finds the mime type of a PDF' );
	ok( defined( $detected->{description} ), 'mime_detect returns a description as well' );

	is( $cape_util->mime_to_package( file => $pdf ), 'pdf', 'mime_to_package detects the mime when given a file' );

	eval { $cape_util->mime_detect( file => $dir . '/does-not-exist' ) };
	ok( $@, 'mime_detect dies on a file that does not exist' );
} ## end SKIP:

eval { $cape_util->mime_detect() };
ok( $@, 'mime_detect dies when passed no file' );

done_testing;
