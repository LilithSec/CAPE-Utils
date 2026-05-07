use utf8;
package CAPE::Utils::Schema::Result::Tag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::Tag

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tags>

=cut

__PACKAGE__->table("tags");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'tags_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "tags_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<tags_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("tags_name_key", ["name"]);

=head1 RELATIONS

=head2 machines_tags

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::MachinesTag>

=cut

__PACKAGE__->has_many(
  "machines_tags",
  "CAPE::Utils::Schema::Result::MachinesTag",
  { "foreign.tag_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tasks_tags

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TasksTag>

=cut

__PACKAGE__->has_many(
  "tasks_tags",
  "CAPE::Utils::Schema::Result::TasksTag",
  { "foreign.tag_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7G/0x78uD5GpOMbslrBERw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
