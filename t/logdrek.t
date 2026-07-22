#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 8;

use_ok('CAPE::Utils::LogDrek') || print "Bail out!\n";

can_ok( 'CAPE::Utils::LogDrek', 'log_drek' );
ok( ( grep { $_ eq 'log_drek' } @CAPE::Utils::LogDrek::EXPORT_OK ), 'log_drek is exportable via @EXPORT_OK' );

#
# intercept the syslog calls so nothing actually hits the system logger and we
# can inspect exactly what log_drek would have emitted
#
my @calls;
my @idents;
no warnings qw( redefine once );
local *CAPE::Utils::LogDrek::openlog  = sub { push( @idents, $_[0] ); };
local *CAPE::Utils::LogDrek::closelog = sub { };
local *CAPE::Utils::LogDrek::syslog   = sub { push( @calls, [@_] ); };
use warnings qw( redefine once );

# syslog is called as syslog( $level, '%s', $message )
CAPE::Utils::LogDrek::log_drek( 'info', 'hello', 5 );
is( $calls[0][2], '5 : hello',  'tracking int is prepended to the message' );
is( $idents[0],   'cape_utils', 'ident defaults to cape_utils' );

CAPE::Utils::LogDrek::log_drek( 'err', 'boom' );
is( $calls[1][2], 'boom', 'message left alone when no tracking int is given' );

@calls = ();
CAPE::Utils::LogDrek::log_drek( undef, 'no level' );
is( $calls[0][0], 'info', 'level defaults to info when undef' );

@idents = ();
CAPE::Utils::LogDrek::log_drek( 'info', 'custom ident', undef, 'mojo_cape_submit' );
is( $idents[0], 'mojo_cape_submit', 'ident can be overridden' );
