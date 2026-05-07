use utf8;
package CAPE::Utils::Schema::Result::TestRun;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::TestRun

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<test_runs>

=cut

__PACKAGE__->table("test_runs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'test_runs_id_seq'

=head2 session_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 test_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 cape_task_id

  data_type: 'integer'
  is_nullable: 1

=head2 status

  data_type: 'varchar'
  is_nullable: 0
  size: 50

=head2 started_at

  data_type: 'timestamp'
  is_nullable: 1

=head2 completed_at

  data_type: 'timestamp'
  is_nullable: 1

=head2 logs

  data_type: 'text'
  is_nullable: 1

=head2 raw_results

  data_type: 'json'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "test_runs_id_seq",
  },
  "session_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "test_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "cape_task_id",
  { data_type => "integer", is_nullable => 1 },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "started_at",
  { data_type => "timestamp", is_nullable => 1 },
  "completed_at",
  { data_type => "timestamp", is_nullable => 1 },
  "logs",
  { data_type => "text", is_nullable => 1 },
  "raw_results",
  { data_type => "json", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 session

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::TestSession>

=cut

__PACKAGE__->belongs_to(
  "session",
  "CAPE::Utils::Schema::Result::TestSession",
  { id => "session_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 test

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::AvailableTest>

=cut

__PACKAGE__->belongs_to(
  "test",
  "CAPE::Utils::Schema::Result::AvailableTest",
  { id => "test_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 test_objective_instances

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TestObjectiveInstance>

=cut

__PACKAGE__->has_many(
  "test_objective_instances",
  "CAPE::Utils::Schema::Result::TestObjectiveInstance",
  { "foreign.run_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lOIq+vasUKR3uC6XyY3LCQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
