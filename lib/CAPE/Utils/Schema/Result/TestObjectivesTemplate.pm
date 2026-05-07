use utf8;
package CAPE::Utils::Schema::Result::TestObjectivesTemplate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::TestObjectivesTemplate

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<test_objectives_templates>

=cut

__PACKAGE__->table("test_objectives_templates");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'test_objectives_templates_id_seq'

=head2 full_name

  data_type: 'varchar'
  is_nullable: 0
  size: 512

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 requirement

  data_type: 'text'
  is_nullable: 1

=head2 parent_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "test_objectives_templates_id_seq",
  },
  "full_name",
  { data_type => "varchar", is_nullable => 0, size => 512 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "requirement",
  { data_type => "text", is_nullable => 1 },
  "parent_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<test_objectives_templates_full_name_key>

=over 4

=item * L</full_name>

=back

=cut

__PACKAGE__->add_unique_constraint("test_objectives_templates_full_name_key", ["full_name"]);

=head1 RELATIONS

=head2 parent

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::TestObjectivesTemplate>

=cut

__PACKAGE__->belongs_to(
  "parent",
  "CAPE::Utils::Schema::Result::TestObjectivesTemplate",
  { id => "parent_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 test_objective_instances

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TestObjectiveInstance>

=cut

__PACKAGE__->has_many(
  "test_objective_instances",
  "CAPE::Utils::Schema::Result::TestObjectiveInstance",
  { "foreign.template_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 test_objectives_templates

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TestObjectivesTemplate>

=cut

__PACKAGE__->has_many(
  "test_objectives_templates",
  "CAPE::Utils::Schema::Result::TestObjectivesTemplate",
  { "foreign.parent_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 test_template_associations

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TestTemplateAssociation>

=cut

__PACKAGE__->has_many(
  "test_template_associations",
  "CAPE::Utils::Schema::Result::TestTemplateAssociation",
  { "foreign.template_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tests

Type: many_to_many

Composing rels: L</test_template_associations> -> test

=cut

__PACKAGE__->many_to_many("tests", "test_template_associations", "test");


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tGmPqK82w1Y3H/L/TrYj7A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
