use utf8;
package CAPE::Utils::Schema::Result::GuacSession;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::GuacSession

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<guac_sessions>

=cut

__PACKAGE__->table("guac_sessions");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'guac_sessions_id_seq'

=head2 token

  data_type: 'varchar'
  is_nullable: 0
  size: 36

=head2 task_id

  data_type: 'integer'
  is_nullable: 0

=head2 vm_label

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 guest_ip

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 created_at

  data_type: 'timestamp'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "guac_sessions_id_seq",
  },
  "token",
  { data_type => "varchar", is_nullable => 0, size => 36 },
  "task_id",
  { data_type => "integer", is_nullable => 0 },
  "vm_label",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "guest_ip",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "created_at",
  { data_type => "timestamp", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<ix_guac_sessions_token>

=over 4

=item * L</token>

=back

=cut

__PACKAGE__->add_unique_constraint("ix_guac_sessions_token", ["token"]);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-11-09 10:27:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HCKNLvbduaZnnYC/4IFMTw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
