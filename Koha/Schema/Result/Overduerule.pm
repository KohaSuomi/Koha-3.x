package Koha::Schema::Result::Overduerule;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Koha::Schema::Result::Overduerule

=cut

__PACKAGE__->table("overduerules");

=head1 ACCESSORS

=head2 branchcode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 categorycode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 delay1

  data_type: 'integer'
  is_nullable: 1

=head2 letter1

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 debarred1

  data_type: 'varchar'
  default_value: 0
  is_nullable: 1
  size: 1

=head2 fine1

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 delay2

  data_type: 'integer'
  is_nullable: 1

=head2 debarred2

  data_type: 'varchar'
  default_value: 0
  is_nullable: 1
  size: 1

=head2 fine2

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=head2 letter2

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 delay3

  data_type: 'integer'
  is_nullable: 1

=head2 letter3

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 debarred3

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 fine3

  data_type: 'float'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "branchcode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "categorycode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "delay1",
  { data_type => "integer", is_nullable => 1 },
  "letter1",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "debarred1",
  { data_type => "varchar", default_value => 0, is_nullable => 1, size => 1 },
  "fine1",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "delay2",
  { data_type => "integer", is_nullable => 1 },
  "debarred2",
  { data_type => "varchar", default_value => 0, is_nullable => 1, size => 1 },
  "fine2",
  { data_type => "float", default_value => 0, is_nullable => 0 },
  "letter2",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "delay3",
  { data_type => "integer", is_nullable => 1 },
  "letter3",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "debarred3",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "fine3",
  { data_type => "float", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("branchcode", "categorycode");

=head1 RELATIONS

=head2 overduerules_transport_types

Type: has_many

Related object: L<Koha::Schema::Result::OverduerulesTransportType>

=cut

__PACKAGE__->has_many(
  "overduerules_transport_types",
  "Koha::Schema::Result::OverduerulesTransportType",
  {
    "foreign.branchcode"   => "self.branchcode",
    "foreign.categorycode" => "self.categorycode",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2015-03-12 13:18:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:22HEaiaaj1dQuEqJI2Qccg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
