use utf8;
package CAPE::Utils::Schema::Result::Task;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::Task

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tasks>

=cut

__PACKAGE__->table("tasks");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'tasks_id_seq'

=head2 target

  data_type: 'text'
  is_nullable: 0

=head2 category

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 cape

  data_type: 'varchar'
  is_nullable: 1
  size: 2048

=head2 timeout

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 priority

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 custom

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 machine

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 package

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 route

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 tags_tasks

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 options

  data_type: 'text'
  is_nullable: 1

=head2 platform

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 memory

  data_type: 'boolean'
  is_nullable: 0

=head2 enforce_timeout

  data_type: 'boolean'
  is_nullable: 0

=head2 clock

  data_type: 'timestamp'
  is_nullable: 0

=head2 added_on

  data_type: 'timestamp'
  is_nullable: 0

=head2 started_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 completed_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 status

  data_type: 'enum'
  default_value: 'pending'
  extra: {custom_type_name => "status_type",list => ["banned","pending","running","completed","distributed","reported","recovered","failed_analysis","failed_processing","failed_reporting"]}
  is_nullable: 0

=head2 dropped_files

  data_type: 'integer'
  is_nullable: 1

=head2 running_processes

  data_type: 'integer'
  is_nullable: 1

=head2 api_calls

  data_type: 'integer'
  is_nullable: 1

=head2 domains

  data_type: 'integer'
  is_nullable: 1

=head2 signatures_total

  data_type: 'integer'
  is_nullable: 1

=head2 signatures_alert

  data_type: 'integer'
  is_nullable: 1

=head2 files_written

  data_type: 'integer'
  is_nullable: 1

=head2 registry_keys_modified

  data_type: 'integer'
  is_nullable: 1

=head2 crash_issues

  data_type: 'integer'
  is_nullable: 1

=head2 anti_issues

  data_type: 'integer'
  is_nullable: 1

=head2 analysis_started_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 analysis_finished_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 processing_started_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 processing_finished_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 signatures_started_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 signatures_finished_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 reporting_started_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 reporting_finished_on

  data_type: 'timestamp'
  is_nullable: 1

=head2 timedout

  data_type: 'boolean'
  is_nullable: 0

=head2 sample_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 machine_id

  data_type: 'integer'
  is_nullable: 1

=head2 tlp

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 user_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "tasks_id_seq",
  },
  "target",
  { data_type => "text", is_nullable => 0 },
  "category",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "cape",
  { data_type => "varchar", is_nullable => 1, size => 2048 },
  "timeout",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "priority",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "custom",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "machine",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "package",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "route",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "tags_tasks",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "options",
  { data_type => "text", is_nullable => 1 },
  "platform",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "memory",
  { data_type => "boolean", is_nullable => 0 },
  "enforce_timeout",
  { data_type => "boolean", is_nullable => 0 },
  "clock",
  { data_type => "timestamp", is_nullable => 0 },
  "added_on",
  { data_type => "timestamp", is_nullable => 0 },
  "started_on",
  { data_type => "timestamp", is_nullable => 1 },
  "completed_on",
  { data_type => "timestamp", is_nullable => 1 },
  "status",
  {
    data_type => "enum",
    default_value => "pending",
    extra => {
      custom_type_name => "status_type",
      list => [
        "banned",
        "pending",
        "running",
        "completed",
        "distributed",
        "reported",
        "recovered",
        "failed_analysis",
        "failed_processing",
        "failed_reporting",
      ],
    },
    is_nullable => 0,
  },
  "dropped_files",
  { data_type => "integer", is_nullable => 1 },
  "running_processes",
  { data_type => "integer", is_nullable => 1 },
  "api_calls",
  { data_type => "integer", is_nullable => 1 },
  "domains",
  { data_type => "integer", is_nullable => 1 },
  "signatures_total",
  { data_type => "integer", is_nullable => 1 },
  "signatures_alert",
  { data_type => "integer", is_nullable => 1 },
  "files_written",
  { data_type => "integer", is_nullable => 1 },
  "registry_keys_modified",
  { data_type => "integer", is_nullable => 1 },
  "crash_issues",
  { data_type => "integer", is_nullable => 1 },
  "anti_issues",
  { data_type => "integer", is_nullable => 1 },
  "analysis_started_on",
  { data_type => "timestamp", is_nullable => 1 },
  "analysis_finished_on",
  { data_type => "timestamp", is_nullable => 1 },
  "processing_started_on",
  { data_type => "timestamp", is_nullable => 1 },
  "processing_finished_on",
  { data_type => "timestamp", is_nullable => 1 },
  "signatures_started_on",
  { data_type => "timestamp", is_nullable => 1 },
  "signatures_finished_on",
  { data_type => "timestamp", is_nullable => 1 },
  "reporting_started_on",
  { data_type => "timestamp", is_nullable => 1 },
  "reporting_finished_on",
  { data_type => "timestamp", is_nullable => 1 },
  "timedout",
  { data_type => "boolean", is_nullable => 0 },
  "sample_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "machine_id",
  { data_type => "integer", is_nullable => 1 },
  "tlp",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "user_id",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 errors

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::Error>

=cut

__PACKAGE__->has_many(
  "errors",
  "CAPE::Utils::Schema::Result::Error",
  { "foreign.task_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 guest

Type: might_have

Related object: L<CAPE::Utils::Schema::Result::Guest>

=cut

__PACKAGE__->might_have(
  "guest",
  "CAPE::Utils::Schema::Result::Guest",
  { "foreign.task_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sample

Type: belongs_to

Related object: L<CAPE::Utils::Schema::Result::Sample>

=cut

__PACKAGE__->belongs_to(
  "sample",
  "CAPE::Utils::Schema::Result::Sample",
  { id => "sample_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 sample_associations

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::SampleAssociation>

=cut

__PACKAGE__->has_many(
  "sample_associations",
  "CAPE::Utils::Schema::Result::SampleAssociation",
  { "foreign.task_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tasks_tags

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TasksTag>

=cut

__PACKAGE__->has_many(
  "tasks_tags",
  "CAPE::Utils::Schema::Result::TasksTag",
  { "foreign.task_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ksYD/Z3xpGUsWoOYdPj3Fg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
