package Koha::Objects;

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
use Scalar::Util qw(blessed);
use Carp;

use Koha::Database;

use Koha::Exception::UnknownObject;
use Koha::Exception::BadParameter;

our $type;

=head1 NAME

Koha::Objects - Koha Object set base class

=head1 SYNOPSIS

    use Koha::Objects;
    my @objects = Koha::Objects->search({ borrowernumber => $borrowernumber});

=head1 DESCRIPTION

This class must be subclassed.

=head1 API

=head2 Class Methods

=cut

=head3 Koha::Objects->new();

my $object = Koha::Objects->new();

=cut

sub new {
    my ($class) = @_;
    my $self = {};

    bless( $self, $class );
}

=head3 Koha::Objects->_new_from_dbic();

my $object = Koha::Objects->_new_from_dbic( $resultset );

=cut

sub _new_from_dbic {
    my ( $class, $resultset ) = @_;
    my $self = { _resultset => $resultset };

    bless( $self, $class );
}

=head _get_castable_unique_columns
@ABSTRACT, OVERLOAD FROM SUBCLASS

Get the columns this Object can use to find a matching Object from the DB.
These columns must be UNIQUE or preferably PRIMARY KEYs.
So if the castable input is not an Object, we can try to find these scalars and do
a DB search using them.
=cut

sub _get_castable_unique_columns {}

=head Koha::Objects->cast();

Try to find a matching Object from the given input. Is basically a validator to
validate the given input and make sure we get a Koha::Object or an Exception.

=head2 An example:

    ### IN Koha/Borrowers.pm ###
    package Koha::Borrowers;
    ...
    sub _get_castable_unique_columns {
        return ['borrowernumber', 'cardnumber', 'userid'];
    }

    ### SOMEWHERE IN A SCRIPT FAR AWAY ###
    my $borrower = Koha::Borrowers->cast('cardnumber');
    my $borrower = Koha::Borrowers->cast($Koha::Borrower);
    my $borrower = Koha::Borrowers->cast('userid');
    my $borrower = Koha::Borrowers->cast('borrowernumber');
    my $borrower = Koha::Borrowers->cast({borrowernumber => 123,
                                        });
    my $borrower = Koha::Borrowers->cast({firstname => 'Olli-Antti',
                                                    surname => 'Kivi',
                                                    address => 'Koskikatu 25',
                                                    cardnumber => '11A001',
                                                    ...
                                        });

=head Description

Because there are gazillion million ways in Koha to invoke an Object, this is a
helper for easily creating different kinds of objects from all the arcane invocations present
in many parts of Koha.
Just throw the crazy and unpredictable return values from myriad subroutines returning
some kind of an objectish value to this casting function to get a brand new Koha::Object.
@PARAM1 Scalar, or HASHRef, or Koha::Object or Koha::Schema::Result::XXX
@RETURNS Koha::Object subclass, possibly already in DB or a completely new one if nothing was
                         inferred from the DB.
@THROWS Koha::Exception::BadParameter, if no idea what to do with the input.
@THROWS Koha::Exception::UnknownObject, if we cannot find an Object with the given input.

=cut

sub cast {
    my ($class, $input) = @_;

    unless ($input) {
        Koha::Exception::BadParameter->throw(error => "$class->cast():> No parameter given!");
    }
    if (blessed($input) && $input->isa( $class->object_class )) {
        return $input;
    }
    if (blessed($input) && $input->isa( 'Koha::Schema::Result::'.$class->type )) {
        return $class->object_class->_new_from_dbic($input);
    }

    my %searchTerms; #Make sure the search terms are processed in the order they have been introduced.
    #Extract unique keys and try to get the object from them.
    my $castableColumns = $class->_get_castable_unique_columns();
    my $resultSource = $class->_resultset()->result_source();

    if (ref($input) eq 'HASH') {
        foreach my $col (@$castableColumns) {
            if ($input->{$col} &&
                    $class->_cast_validate_column( $resultSource->column_info($col), $input->{$col}) ) {
                $searchTerms{$col} = $input->{$col};
            }
        }
    }
    elsif (not(ref($input))) { #We have a scalar
        foreach my $col (@$castableColumns) {
            if ($class->_cast_validate_column( $resultSource->column_info($col), $input) ) {
                $searchTerms{$col} = $input;
            }
        }
    }

    if (scalar(%searchTerms)) {
        my @objects = $class->search({'-or' => \%searchTerms});

        unless (scalar(@objects) == 1) {
            my @keys = keys %searchTerms;
            my $keys = join('|', @keys);
            my @values = values %searchTerms;
            my $values = join('|', @values);
            Koha::Exception::UnknownObject->throw(error => "$class->cast():> Cannot find an existing ".$class->object_class." from $keys '$values'.")
                            if scalar(@objects) < 1;
            Koha::Exception::UnknownObject->throw(error => "$class->cast():> Too many ".$class->object_class."s found with $keys '$values'. Will not possibly return the wrong ".$class->object_class)
                            if scalar(@objects) > 1;
        }
        return $objects[0];
    }

    Koha::Exception::BadParameter->throw(error => "$class->cast():> Unknown parameter '$input' given!");
}

=head _cast_validate_column

    For some reason MySQL decided that it is a good idea to cast String to Integer automatically
    For ex. SELECT * FROM borrowers WHERE borrowernumber = '11A001';
    returns the Borrower with borrowernumber => 11, instead of no results!
    This is potentially catastrophic.
    Validate integers and other data types here.

=cut

sub _cast_validate_column {
    my ($class, $column, $value) = @_;

    if ($column->{data_type} eq 'integer' && $value !~ m/^\d+$/) {
        return 0;
    }
    return 1;
}

=head3 Koha::Objects->find();

my $object = Koha::Objects->find($id);
my $object = Koha::Objects->find( { keypart1 => $keypart1, keypart2 => $keypart2 } );

=cut

sub find {
    my ( $self, $id ) = @_;

    return unless $id;

    my $result = $self->_resultset()->find($id);

    return unless $result;

    my $object = $self->object_class()->_new_from_dbic( $result );

    return $object;
}

=head3 Koha::Objects->search();

my @objects = Koha::Objects->search($params);

=cut

sub search {
    my ( $self, $params ) = @_;

    if (wantarray) {
        my @dbic_rows = $self->_resultset()->search($params);

        return $self->_wrap(@dbic_rows);

    }
    else {
        my $class = ref($self) ? ref($self) : $self;
        my $rs = $self->_resultset()->search($params);

        return $class->_new_from_dbic($rs);
    }
}

=head3 Koha::Objects->count();

my @objects = Koha::Objects->count($params);

=cut

sub count {
    my ( $self, $params ) = @_;

    return $self->_resultset()->count($params);
}

=head3 Koha::Objects->next();

my $object = Koha::Objects->next();

Returns the next object that is part of this set.
Returns undef if there are no more objects to return.

=cut

sub next {
    my ( $self ) = @_;

    my $result = $self->_resultset()->next();
    return unless $result;

    my $object = $self->object_class()->_new_from_dbic( $result );

    return $object;
}

=head3 Koha::Objects->reset();

Koha::Objects->reset();

resets iteration so the next call to next() will start agein
with the first object in a set.

=cut

sub reset {
    my ( $self ) = @_;

    $self->_resultset()->reset();

    return $self;
}

=head3 Koha::Objects->as_list();

Koha::Objects->as_list();

Returns an arrayref of the objects in this set.

=cut

sub as_list {
    my ( $self ) = @_;

    my @dbic_rows = $self->_resultset()->all();

    my @objects = $self->_wrap(@dbic_rows);

    return wantarray ? @objects : \@objects;
}

=head3 Koha::Objects->_wrap

wraps the DBIC object in a corresponding Koha object

=cut

sub _wrap {
    my ( $self, @dbic_rows ) = @_;

    my @objects = map { $self->object_class()->_new_from_dbic( $_ ) } @dbic_rows;

    return @objects;
}

=head3 Koha::Objects->_resultset

Returns the internal resultset or creates it if undefined

=cut

sub _resultset {
    my ($self) = @_;

    if ( ref($self) ) {
        $self->{_resultset} ||=
          Koha::Database->new()->schema()->resultset( $self->type() );

        return $self->{_resultset};
    }
    else {
        return Koha::Database->new()->schema()->resultset( $self->type() );
    }
}

=head3 type

The type method must be set for all child classes.
The value returned by it should be the DBIC resultset name.
For example, for holds, type should return 'Reserve'.

=cut

sub type { }

=head3 object_class

This method must be set for all child classes.
The value returned by it should be the name of the Koha
object class that is returned by this class.
For example, for holds, object_class should return 'Koha::Hold'.

=cut

sub object_class { }

sub DESTROY { }

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
