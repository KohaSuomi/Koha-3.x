package t::db_dependent::TestObjects::Items::ExampleItems;

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

use t::db_dependent::TestObjects::Items::ItemFactory;

=head createTestGroupX

    You should use the appropriate Factory-class to create these test-objects.

=cut

my @testGroup1Identifiers = ('167Nxxx0001', '167Nxxx0002', '167Nxxx0003', '167Nxxx0004',
                             '167Nxxx0005', '167Nxxx0006', '167Nxxx0007', '167Nxxx0008',
                            );

sub shareItemsToBiblios {
    my ($items, $biblios) = @_;
    my @biblioKeys = keys %$biblios;

    for (my $i=0 ; $i<@$items ; $i++) {
        my $item = $items->[$i];
        my $biblioKey = $biblioKeys[ $i % scalar(@$biblios) ]; #Split these Items to each of the Biblios
        my $biblio = $biblios->{$biblioKey};

        unless ($biblio && $biblio->{biblionumber}) {
            carp "ExampleItems:> Item \$barcode '".$item->{barcode}."' doesn't have a biblionumber, skipping.";
            next();
        }
        $item->{biblionumber} = $biblio->{biblionumber};
    }
}

sub createTestGroup1 {
    my $biblios = shift;

    my @items = (
        {barcode => $testGroup1Identifiers[0],
         homebranch => 'CPL', holdingbranch => 'CPL',
         price => '0.5', replacementprice => '0.5', itype => 'BK'
        },
        {barcode => $testGroup1Identifiers[1],
         homebranch => 'CPL', holdingbranch => 'FFL',
         price => '1.5', replacementprice => '1.5', itype => 'BK'
        },
        {barcode => $testGroup1Identifiers[2],
         homebranch => 'CPL', holdingbranch => 'FFL',
         price => '2.5', replacementprice => '2.5', itype => 'BK'
        },
        {barcode => $testGroup1Identifiers[3],
         homebranch => 'FFL', holdingbranch => 'FFL',
         price => '3.5', replacementprice => '3.5', itype => 'BK'
        },
        {barcode => $testGroup1Identifiers[4],
         homebranch => 'FFL', holdingbranch => 'FFL',
         price => '4.5', replacementprice => '4.5', itype => 'VM'
        },
        {barcode => $testGroup1Identifiers[5],
         homebranch => 'FFL', holdingbranch => 'FFL',
         price => '5.5', replacementprice => '5.5', itype => 'VM'
        },
        {barcode => $testGroup1Identifiers[6],
         homebranch => 'FFL', holdingbranch => 'CPL',
         price => '6.5', replacementprice => '6.5', itype => 'VM'
        },
        {barcode => $testGroup1Identifiers[7],
         homebranch => 'CPL', holdingbranch => 'CPL',
         price => '7.5', replacementprice => '7.5', itype => 'VM'
        },
    );

    shareItemsToBiblios(\@items, $biblios);

    return t::db_dependent::TestObjects::Items::ItemFactory::createTestGroup(\@items);
}
sub deleteTestGroup1 {
    t::db_dependent::TestObjects::Items::ItemFactory::_deleteTestGroupFromIdentifiers(\@testGroup1Identifiers);
}

1;