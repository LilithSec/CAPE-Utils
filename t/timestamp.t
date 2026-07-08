#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use CAPE::Utils;

my $cape = CAPE::Utils->new('/nonexistent/cape_utils.ini');

my $timestamp = $cape->timestamp;
like( $timestamp, qr/^\d{2}\-\d{2}\-\d{4}\ \d{2}\:\d{2}\:\d{2}$/, 'timestamp matches mm-dd-yyyy HH:MM:ss' );

my ( $date, $time ) = split( /\ /, $timestamp );
my ( $mon,  $mday, $year ) = split( /\-/, $date );
my ( $hour, $min,  $sec )  = split( /\:/, $time );

ok( $mon >= 1  && $mon <= 12,  'month is sane' );
ok( $mday >= 1 && $mday <= 31, 'day is sane' );
ok( $year >= 2026, 'year is sane' );
ok( $hour >= 0 && $hour <= 23, 'hour is sane' );
ok( $min >= 0  && $min <= 59,  'minute is sane' );
ok( $sec >= 0  && $sec <= 61,  'second is sane' );

done_testing;
