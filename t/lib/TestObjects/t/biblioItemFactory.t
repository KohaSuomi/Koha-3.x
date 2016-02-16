#!/usr/bin/perl

# Copyright KohaSuomi 2016
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
use Test::More;

use t::lib::TestObjects::ItemFactory;
use Koha::Items;
use t::lib::TestObjects::BiblioFactory;
use Koha::Biblios;

my $subtestContext = {};
##Create and Delete. Add one
my $biblios = t::lib::TestObjects::BiblioFactory->createTestGroup([
                    {'biblio.title' => 'I wish I met your mother',
                     'biblio.author'   => 'Pertti Kurikka',
                     'biblio.copyrightdate' => '1960',
                     'biblioitems.isbn'     => '9519671580',
                     'biblioitems.itemtype' => 'BK',
                    },
                ], 'biblioitems.isbn', $subtestContext);
my $objects = t::lib::TestObjects::ItemFactory->createTestGroup([
                    {biblionumber => $biblios->{9519671580}->{biblionumber},
                     barcode => '167Nabe0001',
                     homebranch   => 'CPL',
                     holdingbranch => 'CPL',
                     price     => '0.50',
                     replacementprice => '0.50',
                     itype => 'BK',
                     biblioisbn => '9519671580',
                     itemcallnumber => 'PK 84.2',
                    },
                ], 'barcode', $subtestContext);

is($objects->{'167Nabe0001'}->barcode, '167Nabe0001', "Item '167Nabe0001'.");
##Add one more to test incrementing the subtestContext.
$objects = t::lib::TestObjects::ItemFactory->createTestGroup([
                    {biblionumber => $biblios->{9519671580}->{biblionumber},
                     barcode => '167Nabe0002',
                     homebranch   => 'CPL',
                     holdingbranch => 'FFL',
                     price     => '3.50',
                     replacementprice => '3.50',
                     itype => 'BK',
                     biblioisbn => '9519671580',
                     itemcallnumber => 'JK 84.2',
                    },
                ], 'barcode', $subtestContext);

is($subtestContext->{item}->{'167Nabe0001'}->barcode, '167Nabe0001', "Item '167Nabe0001' from \$subtestContext.");
is($objects->{'167Nabe0002'}->holdingbranch,           'FFL',         "Item '167Nabe0002'.");
is(ref($biblios->{9519671580}), 'MARC::Record', "Biblio 'I wish I met your mother'.");

##Delete objects
t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);
my $object1 = Koha::Items->find({barcode => '167Nabe0001'});
ok (not($object1), "Item '167Nabe0001' deleted");
my $object2 = Koha::Items->find({barcode => '167Nabe0002'});
ok (not($object2), "Item '167Nabe0002' deleted");
my $object3 = Koha::Biblios->find({title => 'I wish I met your mother', author => "Pertti Kurikka"});
ok (not($object2), "Biblio 'I wish I met your mother' deleted");

done_testing();
