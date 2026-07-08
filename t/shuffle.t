#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use CAPE::Utils;

my $cape = CAPE::Utils->new('/nonexistent/cape_utils.ini');

my @original   = ( 1 .. 100 );
my @to_shuffle = @original;
my $shuffled   = $cape->shuffle( \@to_shuffle );

is( ref($shuffled),         'ARRAY', 'returns a array ref' );
is( scalar( @{$shuffled} ), 100,     'same number of items post shuffle' );
is_deeply( [ sort { $a <=> $b } @{$shuffled} ], \@original, 'same items post shuffle' );

my $single = $cape->shuffle( [42] );
is_deeply( $single, [42], 'single item array unchanged' );

done_testing;
