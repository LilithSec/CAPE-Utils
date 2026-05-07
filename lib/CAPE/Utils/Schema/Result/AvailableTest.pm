use utf8;
package CAPE::Utils::Schema::Result::AvailableTest;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::AvailableTest

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<available_tests>

=cut

__PACKAGE__->table("available_tests");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'available_tests_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 payload_notes

  data_type: 'text'
  is_nullable: 1

=head2 result_notes

  data_type: 'text'
  is_nullable: 1

=head2 zip_password

  data_type: 'text'
  is_nullable: 1

=head2 package

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 timeout

  data_type: 'integer'
  is_nullable: 1

=head2 targets

  data_type: 'text'
  is_nullable: 1

=head2 payload_path

  data_type: 'text'
  is_nullable: 0

=head2 module_path

  data_type: 'text'
  is_nullable: 0

=head2 task_config

  data_type: 'json'
  is_nullable: 0

=head2 is_active

  data_type: 'boolean'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "available_tests_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "payload_notes",
  { data_type => "text", is_nullable => 1 },
  "result_notes",
  { data_type => "text", is_nullable => 1 },
  "zip_password",
  { data_type => "text", is_nullable => 1 },
  "package",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "timeout",
  { data_type => "integer", is_nullable => 1 },
  "targets",
  { data_type => "text", is_nullable => 1 },
  "payload_path",
  { data_type => "text", is_nullable => 0 },
  "module_path",
  { data_type => "text", is_nullable => 0 },
  "task_config",
  { data_type => "json", is_nullable => 0 },
  "is_active",
  { data_type => "boolean", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<available_tests_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("available_tests_name_key", ["name"]);

=head1 RELATIONS

=head2 test_runs

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TestRun>

=cut

__PACKAGE__->has_many(
  "test_runs",
  "CAPE::Utils::Schema::Result::TestRun",
  { "foreign.test_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 test_template_associations

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TestTemplateAssociation>

=cut

__PACKAGE__->has_many(
  "test_template_associations",
  "CAPE::Utils::Schema::Result::TestTemplateAssociation",
  { "foreign.test_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 templates

Type: many_to_many

Composing rels: L</test_template_associations> -> template

=cut

__PACKAGE__->many_to_many("templates", "test_template_associations", "template");


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1+K8vVt4xOfl/5TvFVjcnw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
