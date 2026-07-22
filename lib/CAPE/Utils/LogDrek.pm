package CAPE::Utils::LogDrek;

use 5.006;
use strict;
use warnings;
use Exporter    qw( import );
use Sys::Syslog qw( closelog openlog syslog );

=pod

=head1 NAME

CAPE::Utils::LogDrek - Exportable syslog helper shared by the CAPE::Utils scripts.

=head1 VERSION

Version 0.1.0

=cut

our $VERSION = '0.1.0';

our @EXPORT_OK = qw( log_drek );

=head1 SYNOPSIS

    use CAPE::Utils::LogDrek qw( log_drek );

    log_drek( 'info', 'started' );
    log_drek( 'err',  'something broke', $tracking_int );

=head1 DESCRIPTION

This holds the C<log_drek> sub that used to live inside C<mojo_cape_submit>. It
is exported on request so the various front ends can share one implementation
instead of each carrying their own copy.

=head1 EXPORTS

Nothing is exported by default. L</log_drek> is available via C<@EXPORT_OK>.

=head1 FUNCTIONS

=head2 log_drek

Writes a message to syslog, otherwise behaving exactly as the original sub did.

    log_drek( $level, $message, $tracking_int, $ident );

C<$level> defaults to 'info' when undef. When C<$tracking_int> is defined it is
prepended to the message as C<< $tracking_int . ' : ' . $message >>. C<$ident>
is the syslog ident to log under and defaults to 'cape_utils' when undef.

=cut

sub log_drek {
	my ( $level, $message, $tracking_int, $ident ) = @_;

	if ( !defined($level) ) {
		$level = 'info';
	}

	if ( defined($tracking_int) ) {
		$message = $tracking_int . ' : ' . $message;
	}

	if ( !defined($ident) ) {
		$ident = 'cape_utils';
	}

	openlog( $ident, 'cons,pid', 'daemon' );
	syslog( $level, '%s', $message );
	closelog();

	return;
} ## end sub log_drek

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=cut

1;
