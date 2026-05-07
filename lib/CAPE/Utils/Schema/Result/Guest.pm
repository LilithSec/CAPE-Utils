use utf8;
package CAPE::Utils::Schema::Result::Guest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::Guest

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<guests>

=cut

__PACKAGE__->table("guests");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'guests_id_seq'

=head2 status

  data_type: 'varchar'
  is_nullable: 0
  size: 16

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 label

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 platform

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 manager

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 started_on

  data_type: 'timestamp'
  is_nullable: 0

=head2 shutdown_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 task_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "guests_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 16 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "label",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "platform",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "manager",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "started_on",
  { data_type => "timestamp", is_nullable => 0 },
  "shutdown_on",
  { data_type => "timestamp", is_nullable => 1 },
  "task_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<guests_task_id_key>

=over 4

=item * L</task_id>

=back

=cut

__PACKAGE__->add_unique_constraint("guests_task_id_key", ["task_id"]);

=head1 RELATIONS

=head2 task

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::Task>

=cut

__PACKAGE__->belongs_to(
  "task",
  "CAPE::Utils::Schema::Result::Task",
  { id => "task_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Liv1+gGDGF/HSdmqCVeQCg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
