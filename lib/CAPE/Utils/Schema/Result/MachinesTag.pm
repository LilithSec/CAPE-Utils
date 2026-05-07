use utf8;
package CAPE::Utils::Schema::Result::MachinesTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::MachinesTag

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<machines_tags>

=cut

__PACKAGE__->table("machines_tags");

=head1 ACCESSORS

=head2 machine_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 tag_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "machine_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "tag_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 RELATIONS

=head2 machine

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::Machine>

=cut

__PACKAGE__->belongs_to(
  "machine",
  "CAPE::Utils::Schema::Result::Machine",
  { id => "machine_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 tag

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::Tag>

=cut

__PACKAGE__->belongs_to(
  "tag",
  "CAPE::Utils::Schema::Result::Tag",
  { id => "tag_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zs/JgRJ8Y7cEl9XjlD9Tlw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
