package CAPE::Utils::Cmd::Command::munge;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

=head1 NAME

CAPE::Utils::Cmd::Command::munge - Munge a CAPE report JSON.

=head1 VERSION

0.1.0

=cut

our $VERSION = '0.1.0';

=head1 SYNOPSIS

cape_utils munge [B<-i> <config>] B<-r> <report json>

=head1 METHODS

=head2 abstract

Returns the one line description used by the command listing.

=cut

sub abstract {
	return 'munge a report JSON';
}

=head2 usage_desc

Returns the usage string shown in help output.

=cut

sub usage_desc {
	return '%c munge %o';
}

=head2 opt_spec

Returns the L<Getopt::Long::Descriptive> option spec for this command.

=over 4

=item * B<-r> <report json> - The report JSON to munge.

=back

=cut

sub opt_spec {
	my ($class) = @_;
	return ( [ 'report|r=s', 'the report JSON to munge' ], $class->ini_opt, );
}

=head2 validate_args

Ensures a report JSON was passed via B<-r>.

=cut

sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $opt->{report} ) ) {
		$self->usage_error('No report JSON specified via -r');
	}

	return;
}

=head2 execute

Runs the command.

=cut

sub execute {
	my ( $self, $opt, $args ) = @_;

	$self->cape_utils($opt)->munge( file => $opt->{report} );

	return;
}

1;
