package Koha::Schema::Result::OverdueCalendarWeekday;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Koha::Schema::Result::OverdueCalendarWeekday

=cut

__PACKAGE__->table("overdue_calendar_weekdays");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 branchcode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 weekdays

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "branchcode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "weekdays",
  { data_type => "varchar", is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("branchcode_idx", ["branchcode"]);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2015-03-25 19:41:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IkQ8TR3aG/f9AXcVQSfeFQ

=head1 RELATIONS

=head2 overduerules_transport_types

Type: has_many

Related object: L<Koha::Schema::Result::OverduerulesTransportType>

=cut

__PACKAGE__->has_many(
  "overdue_calendar_exceptions",
  "Koha::Schema::Result::OverdueCalendarException",
  {
    "foreign.branchcode"   => "self.branchcode",
  },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
