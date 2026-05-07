use utf8;
package CAPE::Utils::Schema::Result::TasksTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::TasksTag

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tasks_tags>

=cut

__PACKAGE__->table("tasks_tags");

=head1 ACCESSORS

=head2 task_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 tag_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "task_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "tag_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 RELATIONS

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
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 task

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::Task>

=cut

__PACKAGE__->belongs_to(
  "task",
  "CAPE::Utils::Schema::Result::Task",
  { id => "task_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RH6xeJft0XO5eZOtSiXYew


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
