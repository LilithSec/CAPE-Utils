use utf8;
package CAPE::Utils::Schema::Result::TestObjectiveInstance;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::TestObjectiveInstance

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<test_objective_instances>

=cut

__PACKAGE__->table("test_objective_instances");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'test_objective_instances_id_seq'

=head2 template_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 run_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 parent_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 state

  data_type: 'text'
  is_nullable: 1

=head2 state_reason

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "test_objective_instances_id_seq",
  },
  "template_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "run_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "parent_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "state",
  { data_type => "text", is_nullable => 1 },
  "state_reason",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 parent

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::TestObjectiveInstance>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "CAPE::Utils::Schema::Result::TestObjectiveInstance",
  { id => "parent_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 run

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::TestRun>

=cut

__PACKAGE__->belongs_to(
  "run",
  "CAPE::Utils::Schema::Result::TestRun",
  { id => "run_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 template

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::TestObjectivesTemplate>

=cut

__PACKAGE__->belongs_to(
  "template",
  "CAPE::Utils::Schema::Result::TestObjectivesTemplate",
  { id => "template_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 test_objective_instances

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TestObjectiveInstance>

=cut

__PACKAGE__->has_many(
  "test_objective_instances",
  "CAPE::Utils::Schema::Result::TestObjectiveInstance",
  { "foreign.parent_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rIZa0ypoG0dNvmVx+5RWqg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
