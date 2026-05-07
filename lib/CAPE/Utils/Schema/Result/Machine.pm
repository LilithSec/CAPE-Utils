use utf8;
package CAPE::Utils::Schema::Result::Machine;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::Machine

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<machines>

=cut

__PACKAGE__->table("machines");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'machines_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 label

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 arch

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 ip

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 platform

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 interface

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 snapshot

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 locked

  data_type: 'boolean'
  is_nullable: 0

=head2 locked_changed_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 status_changed_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 resultserver_ip

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 resultserver_port

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 reserved

  data_type: 'boolean'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "machines_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "label",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "arch",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "ip",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "platform",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "interface",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "snapshot",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "locked",
  { data_type => "boolean", is_nullable => 0 },
  "locked_changed_on",
  { data_type => "timestamp", is_nullable => 1 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "status_changed_on",
  { data_type => "timestamp", is_nullable => 1 },
  "resultserver_ip",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "resultserver_port",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "reserved",
  { data_type => "boolean", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<machines_label_key>

=over 4

=item * L</label>

=back

=cut

__PACKAGE__->add_unique_constraint("machines_label_key", ["label"]);

=head2 C<machines_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("machines_name_key", ["name"]);

=head1 RELATIONS

=head2 machines_tags

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::MachinesTag>

=cut

__PACKAGE__->has_many(
  "machines_tags",
  "CAPE::Utils::Schema::Result::MachinesTag",
  { "foreign.machine_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4Oz+h9MRZsorfzY6wjUpqQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
