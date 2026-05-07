use utf8;
package CAPE::Utils::Schema::Result::TestTemplateAssociation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::TestTemplateAssociation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<test_template_association>

=cut

__PACKAGE__->table("test_template_association");

=head1 ACCESSORS

=head2 test_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 template_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "test_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "template_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</test_id>

=item * L</template_id>

=back

=cut

__PACKAGE__->set_primary_key("test_id", "template_id");

=head1 RELATIONS

=head2 template

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::TestObjectivesTemplate>

=cut

__PACKAGE__->belongs_to(
  "template",
  "CAPE::Utils::Schema::Result::TestObjectivesTemplate",
  { id => "template_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 test

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::AvailableTest>

=cut

__PACKAGE__->belongs_to(
  "test",
  "CAPE::Utils::Schema::Result::AvailableTest",
  { id => "test_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:givQuxDvQNXYzVcnUNMFVg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
