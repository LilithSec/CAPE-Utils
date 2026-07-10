package CAPE::Utils::Cmd::Command::eve;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

=head1 NAME

CAPE::Utils::Cmd::Command::eve - Process the CAPE EVE output.

=head1 VERSION

0.1.0

=cut

our $VERSION = '0.1.0';

=head1 SYNOPSIS

cape_utils eve [B<-i> <config>]

=head1 METHODS

=head2 abstract

Returns the one line description used by the command listing.

=cut

sub abstract {
	return 'invoke CAPE::Utils->eve_process';
}

=head2 usage_desc

Returns the usage string shown in help output.

=cut

sub usage_desc {
	return '%c eve %o';
}

=head2 opt_spec

Returns the L<Getopt::Long::Descriptive> option spec for this command.

=cut

sub opt_spec {
	my ($class) = @_;
	return ( $class->ini_opt, );
}

=head2 execute

Runs the command.

=cut

sub execute {
	my ( $self, $opt, $args ) = @_;

	$self->cape_utils($opt)->eve_process();

	return;
}

1;
