package Koha::Object;

# Copyright ByWater Solutions 2014
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Carp;

use Koha::Database;

=head1 NAME

Koha::Object - Koha Object base class

=head1 SYNOPSIS

    use Koha::Object;
    my $object = Koha::Object->new({ property1 => $property1, property2 => $property2, etc... } );

=head1 DESCRIPTION

This class must always be subclassed.

=head1 API

=head2 Class Methods

=cut

=head3 Koha::Object->new();

my $object = Koha::Object->new();
my $object = Koha::Object->new($attributes);

Note that this cannot be used to retrieve record from the DB.

=cut

sub new {
    my ( $class, $attributes ) = @_;
    my $self = {};

    if ($attributes) {
        $self->{_result} =
          Koha::Database->new()->schema()->resultset( $class->type() )
          ->new($attributes);
    }

    croak("No type found! Koha::Object must be subclassed!")
      unless $class->type();

    bless( $self, $class );

}

=head3 Koha::Object->_new_from_dbic();

my $object = Koha::Object->_new_from_dbic($dbic_row);

=cut

sub _new_from_dbic {
    my ( $class, $dbic_row ) = @_;
    my $self = {};

    # DBIC result row
    $self->{_result} = $dbic_row;

    croak("No type found! Koha::Object must be subclassed!")
      unless $class->type();

    croak( "DBIC result type " . ref( $self->{_result} ) . " isn't of the type " . $class->type() )
      unless ref( $self->{_result} ) eq "Koha::Schema::Result::" . $class->type();

    bless( $self, $class );

}

=head3 $object->store();

Saves the object in storage.
If the object is new, it will be created.
If the object previously existed, it will be updated.

Returns:
    1  if the store was a success
    0  if the store failed

=cut

sub store {
    my ($self) = @_;

    return $self->_result()->update_or_insert() ? $self : undef;
}

=head3 $object->in_storage();

Returns true if the object has been previously stored.

=cut

sub in_storage {
    my ($self) = @_;

    return $self->_result()->in_storage();
}

=head3 $object->is_changed();

Returns true if the object has properties that are different from
the properties of the object in storage.

=cut

sub is_changed {
    my ( $self, @columns ) = @_;

    return $self->_result()->is_changed(@columns);
}

=head3 $object->delete();

Removes the object from storage.

Returns:
    1  if the deletion was a success
    0  if the deletion failed
    -1 if the object was never in storage

=cut

sub delete {
    my ($self) = @_;

    # Deleting something not in storage thows an exception
    return -1 unless $self->_result()->in_storage();

    # Return a boolean for succcess
    return $self->_result()->delete() ? 1 : 0;
}

=head3 $object->set( $properties_hashref )

$object->set(
    {
        property1 => $property1,
        property2 => $property2,
        property3 => $propery3,
    }
);

Enables multiple properties to be set at once

Returns:
    1      if all properties were set.
    0      if one or more properties do not exist.
    undef  if all properties exist but a different error
           prevents one or more properties from being set.

If one or more of the properties do not exist,
no properties will be set.

=cut

sub set {
    my ( $self, $properties ) = @_;

    my @columns = @{$self->_columns()};

    foreach my $p ( keys %$properties ) {
        unless ( grep {/^$p$/} @columns ) {
            carp("No property $p!");
            return 0;
        }
    }

    return $self->_result()->set_columns($properties) ? $self : undef;
}

=head3 $object->id();

Returns the id of the object if it has one.

=cut

sub id {
    my ($self) = @_;

    my ( $id ) = $self->_result()->id();

    return $id;
}

=head3 $object->_result();

Returns the internal DBIC Row object

=cut

sub _result {
    my ($self) = @_;

    # If we don't have a dbic row at this point, we need to create an empty one
    $self->{_result} ||=
      Koha::Database->new()->schema()->resultset( $self->type() )->new({});

    return $self->{_result};
}

=head3 $object->_columns();

Returns an arrayref of the table columns

=cut

sub _columns {
    my ($self) = @_;

    # If we don't have a dbic row at this point, we need to create an empty one
    $self->{_columns} ||= [ $self->_result()->result_source()->columns() ];

    return $self->{_columns};
}


=head3 AUTOLOAD

The autoload method is used only to get and set values for an objects properties.

=cut

sub AUTOLOAD {
    my $self = shift;

    my $method = our $AUTOLOAD;
    $method =~ s/.*://;

    my @columns = @{$self->_columns()};
    # Using direct setter/getter like $item->barcode() or $item->barcode($barcode);
    if ( grep {/^$method$/} @columns ) {
        if ( @_ ) {
            return $self->_result()->set_column( $method, @_ );
        } else {
            my $value = $self->_result()->get_column( $method );
            return $value;
        }
    }

    carp "No method $method!";
    return;
}

=head3 type

This method must be defined in the child class. The value is the name of the DBIC resultset.
For example, for borrowers, the type method will return "Borrower".

=cut

sub type { }

sub DESTROY { }

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
