use utf8;
package CAPE::Utils::Schema::Result::TestSession;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

CAPE::Utils::Schema::Result::TestSession

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<test_sessions>

=cut

__PACKAGE__->table("test_sessions");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'test_sessions_id_seq'

=head2 added_on

  data_type: 'timestamp'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "test_sessions_id_seq",
  },
  "added_on",
  { data_type => "timestamp", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 test_runs

Type: has_many

Related object: L<CAPE::Utils::Schema::Result::TestRun>

=cut

__PACKAGE__->has_many(
  "test_runs",
  "CAPE::Utils::Schema::Result::TestRun",
  { "foreign.session_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2026-05-07 19:58:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3uQm145yn4Tx2wNuvaTluw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
