package CAPE::Utils::Cmd::Base;

use strict;
use warnings;
use parent 'App::Cmd::Command';
use CAPE::Utils;
use JSON;

our $VERSION = '0.1.0';

sub ini_opt {
	return [ 'ini|i=s', 'config INI file, default /usr/local/etc/cape_utils.ini' ];
}

sub json_opts {
	return ( [ 'json', 'output the result as JSON' ], [ 'pretty', 'pretty print the JSON output' ], );
}

sub cape_utils {
	my ( $self, $opt ) = @_;

	if ( !defined( $self->{cape_utils} ) ) {
		$self->{cape_utils} = CAPE::Utils->new( $opt->{ini} );
	}

	return $self->{cape_utils};
}

sub print_json {
	my ( $self, $opt, $data ) = @_;

	my $j = JSON->new;
	if ( $opt->{pretty} ) {
		$j->pretty(1);
	}
	print $j->encode($data);
	if ( !$opt->{pretty} ) {
		print "\n";
	}

	return;
} ## end sub print_json

1;
