use utf8;
package CAPE::Utils::Schema::Result::Error;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::Error

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<errors>

=cut

__PACKAGE__->table("errors");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'errors_id_seq'

=head2 message

  data_type: 'varchar'
  is_nullable: 0
  size: 1024

=head2 task_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "errors_id_seq",
  },
  "message",
  { data_type => "varchar", is_nullable => 0, size => 1024 },
  "task_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 task

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::Task>

=cut

__PACKAGE__->belongs_to(
  "task",
  "CAPE::Utils::Schema::Result::Task",
  { id => "task_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:znw7+60czzZEdv5QUJNS5Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
