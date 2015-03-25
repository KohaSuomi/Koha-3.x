package t::db_dependent::TestObjects::Items::ItemFactory;

# Copyright Vaara-kirjastot 2015
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
#

use Modern::Perl;
use Carp;

use C4::Items;

use t::db_dependent::TestObjects::Items::ExampleItems;
use t::db_dependent::TestObjects::ObjectFactory;

=head t::db_dependent::TestObjects::Items::ItemFactory::createTestGroup( $data [, $hashKey] )
Returns a HASH of objects.
Each Item is expected to contain the biblionumber of the Biblio they are added into.
    eg. $item->{biblionumber} = 550242;

The HASH is keyed with the PRIMARY KEY, or the given $hashKey.

See C4::Items::AddItem() for how the table columns need to be given.
=cut

sub createTestGroup {
    my ($objects, $hashKey) = @_;

    my %objects;
    foreach my $object (@$objects) {
        my ($biblionumber, $biblioitemnumber, $itemnumber) = C4::Items::AddItem($object, $object->{biblionumber});
        my $item = C4::Items::GetItem($itemnumber, undef);
        unless ($item) {
            carp "ItemFactory:> No item for barcode '".$object->{barcode}."'";
            next();
        }

        my $key = t::db_dependent::TestObjects::ObjectFactory::getHashKey($item, $itemnumber, $hashKey);

        $objects{$key} = $item;
    }
    return \%objects;
}

=head

    my $objects = createTestGroup();
    ##Do funky stuff
    deleteTestGroup($records);

Removes the given test group from the DB.

=cut

sub deleteTestGroup {
    my $objects = shift;

    my $schema = Koha::Database->new_schema();
    while( my ($key, $object) = each %$objects) {
        $schema->resultset('Item')->find($object->{itemnumber})->delete();
    }
}
sub _deleteTestGroupFromIdentifiers {
    my $testGroupIdentifiers = shift;

    my $schema = Koha::Database->new_schema();
    foreach my $key (@$testGroupIdentifiers) {
        $schema->resultset('Item')->find({"barcode" => $key})->delete();
    }
}

sub createTestGroup1 {
    return t::db_dependent::TestObjects::Items::ExampleItems::createTestGroup1();
}
sub deleteTestGroup1 {
    return t::db_dependent::TestObjects::Items::ExampleItems::deleteTestGroup1();
}

1;