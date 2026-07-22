package CAPE::Utils::Cmd;

use strict;
use warnings;
use App::Cmd::Setup -app;

our $VERSION = '0.1.0';

=head2 legacy_rewrite

Backwards compatibility shim for the pre-L<App::Cmd> command line, which used
C<cape_utils -a E<lt>actionE<gt>> with C<-c>/C<--config> for the INI file.

Given an argument list (typically C<@ARGV>), it returns a rewritten list suitable
for L<App::Cmd>. If the legacy C<-a>/C<--action> flag is not present, the list is
returned unchanged so native invocations are untouched. When it is present, the
action becomes the leading positional (the sub command) and any C<-c>/C<--config>
is mapped to C<-i>.

    @ARGV = CAPE::Utils::Cmd->legacy_rewrite(@ARGV);

Recognized forms for both flags: C<-a submit>, C<-a=submit>, C<--action submit>,
and C<--action=submit>.

=cut

sub legacy_rewrite {
	my ( $class, @argv ) = @_;

	# only engage compat mode if the legacy -a/--action flag is present
	return @argv unless grep { /\A(?:-a|--action)(?:=|\z)/ } @argv;

	my ( $action, @rest );
	while ( defined( my $tok = shift @argv ) ) {
		if    ( $tok =~ /\A(?:-a|--action)=(.*)\z/ ) { $action = $1 }
		elsif ( $tok =~ /\A(?:-a|--action)\z/ )      { $action = shift @argv }
		elsif ( $tok =~ /\A(?:-c|--config)=(.*)\z/ ) { push @rest, '-i', $1 }
		elsif ( $tok =~ /\A(?:-c|--config)\z/ )      { push @rest, '-i', shift @argv }
		else                                         { push @rest, $tok }
	}

	# action becomes the sub command; drop it if it never got a value
	return defined($action) ? ( $action, @rest ) : @rest;
} ## end sub legacy_rewrite

1;
