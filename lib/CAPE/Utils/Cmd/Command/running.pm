package CAPE::Utils::Cmd::Command::running;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

=head1 NAME

CAPE::Utils::Cmd::Command::running - Show running CAPE tasks.

=head1 VERSION

0.1.0

=cut

our $VERSION = '0.1.0';

=head1 SYNOPSIS

cape_utils running [B<-i> <config>] [B<-C>] [B<-w> <where>] [B<--json>] [B<--pretty>]

=head1 METHODS

=head2 abstract

Returns the one line description used by the command listing.

=cut

sub abstract {
	return 'show running tasks';
}

=head2 usage_desc

Returns the usage string shown in help output.

=cut

sub usage_desc {
	return '%c running %o';
}

=head2 opt_spec

Returns the L<Getopt::Long::Descriptive> option spec for this command.

=over 4

=item * B<-C> - Print the running count instead of the table.

=item * B<-w> <where> - Additional SQL args for use with the statement getting running items.

=back

=cut

sub opt_spec {
	my ($class) = @_;
	return (
		[ 'count|C',   'print the running count instead of the table' ],
		[ 'where|w=s', 'additional SQL args for use when getting running items' ],
		$class->json_opts, $class->ini_opt,
	);
}

=head2 execute

Runs the command.

=cut

sub execute {
	my ( $self, $opt, $args ) = @_;

	my $cape_utils = $self->cape_utils($opt);

	if ( $opt->{count} ) {
		print $cape_utils->get_running_count( where => $opt->{where} ) . "\n";
	} elsif ( $opt->{json} ) {
		$self->print_json( $opt, $cape_utils->get_running( where => $opt->{where} ) );
	} else {
		print $cape_utils->get_running_table( where => $opt->{where} );
	}

	return;
} ## end sub execute

1;
