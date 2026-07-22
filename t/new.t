#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp  qw( tempdir );
use File::Slurp qw( write_file );

use CAPE::Utils;

my $tempdir = tempdir( CLEANUP => 1 );

#
# no config file... should use the defaults
#
my $cape = CAPE::Utils->new( $tempdir . '/does_not_exist.ini' );
isa_ok( $cape, 'CAPE::Utils' );
is( $cape->{config}->{_}->{dsn},              'dbi:Pg:dbname=cape',          'default dsn' );
is( $cape->{config}->{_}->{user},             'cape',                        'default user' );
is( $cape->{config}->{_}->{pass},             '',                            'default pass' );
is( $cape->{config}->{_}->{base},             '/opt/CAPEv2/',                'default base' );
is( $cape->{config}->{_}->{poetry},           1,                             'default poetry' );
is( $cape->{config}->{_}->{fail_all},         0,                             'default fail_all' );
is( $cape->{config}->{_}->{timeout},          200,                           'default timeout' );
is( $cape->{config}->{_}->{enforce_timeout},  0,                             'default enforce_timeout' );
is( $cape->{config}->{_}->{auth},             'ip',                          'default auth' );
is( $cape->{config}->{_}->{set_clock_to_now}, 1,                             'default set_clock_to_now' );
is( $cape->{config}->{_}->{eve_look_back},    360,                           'default eve_look_back' );
SKIP: {
       my $template_file = '/usr/local/etc/cape_utils_link_format_template.t2';
       skip "$template_file exists and overrides the default", 1 if -f $template_file;
       is( $cape->{config}->{_}->{post_link_format_template},
               '[% lite.target.file.name %]', 'default post_link_format_template' );
}

#
# config file with some items set... set items should be used and the rest merged from the defaults
#
my $ini = $tempdir . '/cape_utils.ini';
write_file( $ini, "dsn=dbi:Pg:dbname=sandbox\ntimeout=500\nauth=apikey\napikey=foo\n" );
my $cape2 = CAPE::Utils->new($ini);
isa_ok( $cape2, 'CAPE::Utils' );
is( $cape2->{config}->{_}->{dsn},     'dbi:Pg:dbname=sandbox', 'dsn from config file' );
is( $cape2->{config}->{_}->{timeout}, 500,                     'timeout from config file' );
is( $cape2->{config}->{_}->{auth},    'apikey',                'auth from config file' );
is( $cape2->{config}->{_}->{apikey},  'foo',                   'apikey from config file' );
is( $cape2->{config}->{_}->{base},    '/opt/CAPEv2/',          'unset item merged from defaults' );
is(
	$cape2->{config}->{_}->{subnets},
	'192.168.0.0/16,127.0.0.1/8,::1/128,172.16.0.0/12,10.0.0.0/8',
	'unset subnets merged from defaults'
);

#
# post_link_format_template_file, when it exists, replaces post_link_format_template
#
my $template_file = $tempdir . '/link_format_template.t2';
write_file( $template_file, '[% lite.target.file.sha256 %]' );
my $ini3 = $tempdir . '/cape_utils_template.ini';
write_file( $ini3, "post_link_format_template_file=$template_file\n" );
my $cape3 = CAPE::Utils->new($ini3);
is( $cape3->{config}->{_}->{post_link_format_template},
       '[% lite.target.file.sha256 %]',
       'post_link_format_template read from post_link_format_template_file'
);


done_testing;
