#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

use_ok('CAPE::Utils') || print "Bail out!\n";

# in-subnet vs out-of-subnet IPs for the default subnet list
my $in_ip  = '192.168.1.5';
my $out_ip = '8.8.8.8';

# helper to build a CAPE::Utils with the submission ACL config forced to
# specific values, bypassing any on disk ini
sub cape_with {
	my (%cfg) = @_;
	my $cape = CAPE::Utils->new('/nonexistent-cape_utils.ini');
	foreach my $key ( keys %cfg ) {
		$cape->{config}{_}{$key} = $cfg{$key};
	}
	return $cape;
}

#
# ip mode: only the IP matters
#
my $ip_mode = cape_with( auth => 'ip', apikey => 'secret' );
ok( $ip_mode->check_remote( ip => $in_ip ),                       'ip: in-subnet, no key allowed' );
ok( !$ip_mode->check_remote( ip => $out_ip ),                     'ip: out-of-subnet, no key denied' );
ok( $ip_mode->check_remote( ip => $in_ip, apikey => 'wrong' ),    'ip: in-subnet allowed regardless of key' );
ok( !$ip_mode->check_remote( ip => $out_ip, apikey => 'secret' ), 'ip: out-of-subnet denied even with valid key' );

#
# apikey mode: only the key matters
#
my $key_mode = cape_with( auth => 'apikey', apikey => 'secret' );
ok( $key_mode->check_remote( ip  => $out_ip, apikey => 'secret' ), 'apikey: right key allowed from any IP' );
ok( !$key_mode->check_remote( ip => $in_ip,  apikey => 'wrong' ),  'apikey: wrong key denied' );
ok( !$key_mode->check_remote( ip => $in_ip ), 'apikey: no key denied' );

# an empty configured key must never match
my $empty_key = cape_with( auth => 'apikey', apikey => '' );
ok( !$empty_key->check_remote( ip => $in_ip, apikey => '' ), 'apikey: empty configured key never matches' );

#
# both mode: IP and key must both pass
#
my $both_mode = cape_with( auth => 'both', apikey => 'secret' );
ok( $both_mode->check_remote( ip  => $in_ip,  apikey => 'secret' ), 'both: in-subnet + right key allowed' );
ok( !$both_mode->check_remote( ip => $in_ip,  apikey => 'wrong' ),  'both: in-subnet + wrong key denied' );
ok( !$both_mode->check_remote( ip => $out_ip, apikey => 'secret' ), 'both: out-of-subnet + right key denied' );

#
# either mode: IP or key passes
#
my $either_mode = cape_with( auth => 'either', apikey => 'secret' );
ok( $either_mode->check_remote( ip  => $in_ip,  apikey => 'wrong' ),  'either: in-subnet is enough' );
ok( $either_mode->check_remote( ip  => $out_ip, apikey => 'secret' ), 'either: right key is enough' );
ok( !$either_mode->check_remote( ip => $out_ip, apikey => 'wrong' ),  'either: neither denied' );

#
# check_remote_results uses the separate results_* config, independent of the
# submission config
#
my $results = cape_with(
	auth            => 'apikey',       # submission wide open on key would allow...
	apikey          => 'sub',
	results_auth    => 'ip',           # ...but results is ip gated
	results_subnets => '10.0.0.0/8',
	results_apikey  => '',
);
ok( $results->check_remote_results( ip  => '10.1.2.3' ), 'results: in results_subnets allowed' );
ok( !$results->check_remote_results( ip => $in_ip ),     'results: outside results_subnets denied' );
ok( $results->check_remote( ip => $out_ip, apikey => 'sub' ), 'submission ACL is unaffected by results config' );

done_testing();
