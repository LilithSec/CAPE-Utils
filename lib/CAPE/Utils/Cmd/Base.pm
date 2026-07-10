package CAPE::Utils::Cmd::Base;

use strict;
use warnings;
use parent 'App::Cmd::Command';
use CAPE::Utils;
use JSON;

=head1 NAME

CAPE::Utils::Cmd::Base - Base class shared between the cape_utils commands.

=head1 VERSION

0.1.0

=cut

our $VERSION = '0.1.0';

=head1 DESCRIPTION

Base class for the commands found under the C<CAPE::Utils::Cmd::Command> namespace.
It provides the options and helper methods that are common to more than one command.

=head1 METHODS

=head2 ini_opt

Returns the L<Getopt::Long::Descriptive> option spec tuple used for selecting the
INI config file. Commands should splice this into their own C<opt_spec>.

    sub opt_spec {
        my ($class) = @_;
        return ( ..., $class->ini_opt );
    }

=cut

sub ini_opt {
	return [ 'ini|i=s', 'config INI file, default /usr/local/etc/cape_utils.ini' ];
}

=head2 json_opts

Returns the list of L<Getopt::Long::Descriptive> option spec tuples used for JSON
output, C<--json> and C<--pretty>. Commands that support JSON output should splice
these into their own C<opt_spec>.

=cut

sub json_opts {
	return ( [ 'json', 'output the result as JSON' ], [ 'pretty', 'pretty print the JSON output' ], );
}

=head2 cape_utils

Returns a L<CAPE::Utils> object built from the C<--ini> option. The object is
cached for the lifetime of the command instance.

    my $cape_utils = $self->cape_utils($opt);

=cut

sub cape_utils {
	my ( $self, $opt ) = @_;

	if ( !defined( $self->{cape_utils} ) ) {
		$self->{cape_utils} = CAPE::Utils->new( $opt->{ini} );
	}

	return $self->{cape_utils};
}

=head2 print_json

Encodes the passed data structure as JSON and prints it to STDOUT, honoring the
C<--pretty> option.

    $self->print_json( $opt, $data );

=cut

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
