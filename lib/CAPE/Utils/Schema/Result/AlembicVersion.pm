use utf8;
package CAPE::Utils::Schema::Result::AlembicVersion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::AlembicVersion

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<alembic_version>

=cut

__PACKAGE__->table("alembic_version");

=head1 ACCESSORS

=head2 version_num

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=cut

__PACKAGE__->add_columns(
  "version_num",
  { data_type => "varchar", is_nullable => 0, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</version_num>

=back

=cut

__PACKAGE__->set_primary_key("version_num");


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:atezePMi8lIy5M9Dpz5F0w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
