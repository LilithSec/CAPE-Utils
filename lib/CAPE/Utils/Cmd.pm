package CAPE::Utils::Cmd;

use strict;
use warnings;
use App::Cmd::Setup -app;

=head1 NAME

CAPE::Utils::Cmd - App::Cmd application implementing the cape_utils command line tool.

=head1 VERSION

0.1.0

=cut

our $VERSION = '0.1.0';

=head1 SYNOPSIS

    use CAPE::Utils::Cmd;
    CAPE::Utils::Cmd->run;

=head1 DESCRIPTION

This is the L<App::Cmd> application powering the L<cape_utils> script. Each action
is implemented as an individual command under the C<CAPE::Utils::Cmd::Command>
namespace. See L<CAPE::Utils::Cmd::Base> for the functionality shared between the
commands.

The available commands are:

=over 4

=item * L<pending|CAPE::Utils::Cmd::Command::pending>

=item * L<running|CAPE::Utils::Cmd::Command::running>

=item * L<tasks|CAPE::Utils::Cmd::Command::tasks>

=item * L<submit|CAPE::Utils::Cmd::Command::submit>

=item * L<fail|CAPE::Utils::Cmd::Command::fail>

=item * L<eve|CAPE::Utils::Cmd::Command::eve>

=item * L<munge|CAPE::Utils::Cmd::Command::munge>

=item * L<post|CAPE::Utils::Cmd::Command::post>

=back

=head1 CONFIG FILE

For this, see the docs for L<CAPE::Utils>.

Out of the box, it will work by default with CAPEv2 in it's default config.

=cut

1;
