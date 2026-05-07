use utf8;
package CAPE::Utils::Schema::Result::Sample;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::Sample

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<samples>

=cut

__PACKAGE__->table("samples");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'samples_id_seq'

=head2 file_size

  data_type: 'bigint'
  is_nullable: 0

=head2 file_type

  data_type: 'text'
  is_nullable: 0

=head2 md5

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 crc32

  data_type: 'varchar'
  is_nullable: 0
  size: 8

=head2 sha1

  data_type: 'varchar'
  is_nullable: 0
  size: 40

=head2 sha256

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 sha512

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 ssdeep

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 source_url

  data_type: 'varchar'
  is_nullable: 1
  size: 2000

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "samples_id_seq",
  },
  "file_size",
  { data_type => "bigint", is_nullable => 0 },
  "file_type",
  { data_type => "text", is_nullable => 0 },
  "md5",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "crc32",
  { data_type => "varchar", is_nullable => 0, size => 8 },
  "sha1",
  { data_type => "varchar", is_nullable => 0, size => 40 },
  "sha256",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "sha512",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "ssdeep",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "source_url",
  { data_type => "varchar", is_nullable => 1, size => 2000 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<sha256_index>

=over 4

=item * L</sha256>

=back

=cut

__PACKAGE__->add_unique_constraint("sha256_index", ["sha256"]);

=head1 RELATIONS

=head2 sample_associations_children

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::SampleAssociation>

=cut

__PACKAGE__->has_many(
  "sample_associations_children",
  "CAPE::Utils::Schema::Result::SampleAssociation",
  { "foreign.child_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sample_associations_parents

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::SampleAssociation>

=cut

__PACKAGE__->has_many(
  "sample_associations_parents",
  "CAPE::Utils::Schema::Result::SampleAssociation",
  { "foreign.parent_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tasks

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::Task>

=cut

__PACKAGE__->has_many(
  "tasks",
  "CAPE::Utils::Schema::Result::Task",
  { "foreign.sample_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nsRY+RDsm3qUjUG2orYIGA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
