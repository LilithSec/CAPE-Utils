package CAPE::Utils::Cmd::Command::fail;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

=head1 NAME

CAPE::Utils::Cmd::Command::fail - Fail pending CAPE tasks.

=head1 VERSION

0.1.0

=cut

our $VERSION = '0.1.0';

=head1 SYNOPSIS

cape_utils fail [B<-i> <config>] B<-w> <where>

=head1 METHODS

=head2 abstract

Returns the one line description used by the command listing.

=cut

sub abstract {
	return 'fail pending tasks';
}

=head2 usage_desc

Returns the usage string shown in help output.

=cut

sub usage_desc {
	return '%c fail %o';
}

=head2 opt_spec

Returns the L<Getopt::Long::Descriptive> option spec for this command.

=over 4

=item * B<-w> <where> - Additional SQL args for use with the statement failing pending items.

=back

=cut

sub opt_spec {
	my ($class) = @_;
	return ( [ 'where|w=s', 'additional SQL args for use when failing pending items' ], $class->ini_opt, );
}

=head2 execute

Runs the command.

=cut

sub execute {
	my ( $self, $opt, $args ) = @_;

	print $self->cape_utils($opt)->fail( where => $opt->{where} );

	return;
}

1;
