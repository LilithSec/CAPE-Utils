use utf8;
package CAPE::Utils::Schema::Result::SampleAssociation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::SampleAssociation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sample_associations>

=cut

__PACKAGE__->table("sample_associations");

=head1 ACCESSORS

=head2 parent_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 child_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 task_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "parent_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "child_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "task_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</parent_id>

=item * L</child_id>

=item * L</task_id>

=back

=cut

__PACKAGE__->set_primary_key("parent_id", "child_id", "task_id");

=head1 RELATIONS

=head2 child

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::Sample>

=cut

__PACKAGE__->belongs_to(
  "child",
  "CAPE::Utils::Schema::Result::Sample",
  { id => "child_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 parent

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::Sample>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "CAPE::Utils::Schema::Result::Sample",
  { id => "parent_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BZ7BXm2/PKxC+AvN7vpx6g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
