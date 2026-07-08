#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use CAPE::Utils;

my $cape = CAPE::Utils->new('/nonexistent/cape_utils.ini');

#
# all methods taking a where option should die if it contains a ';'
# these all die prior to connecting to the DB, so no DB is needed
#
my @where_methods = (
	'fail',              'get_pending_count', 'get_pending',     'get_running',
	'get_running_count', 'get_tasks',         'get_tasks_count', 'search',
);
foreach my $method (@where_methods) {
	eval { $cape->$method( where => "target = 'foo'; drop table tasks" ); };
	like( $@, qr/contains\ a\ \"\;\"/, $method . ' dies if where contains a ";"' );
}

#
# fail requires a where statement unless fail_all is enabled
#
is( $cape->{config}->{_}->{fail_all}, 0, 'fail_all defaults to off' );
eval { $cape->fail; };
like( $@, qr/fail_all\ is\ disabled/, 'fail dies with no where when fail_all is off' );

#
# get_tasks option validation
#
eval { $cape->get_tasks( order => 'id; drop table tasks' ); };
like( $@, qr/does\ not\ match/, 'get_tasks dies on a invalid order' );

eval { $cape->get_tasks( limit => 'ten' ); };
like( $@, qr/does\ not\ match/, 'get_tasks dies on a non-numeric limit' );

#
# search helpers may not contain a ' or a \
#
eval { $cape->search( target => "fo'o" ); };
like( $@, qr/matched/, 'search dies if a string helper contains a single quote' );

eval { $cape->search( id => '1\\' ); };
like( $@, qr/matched/, 'search dies if a helper contains a backslash' );

done_testing;
