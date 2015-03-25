package t::db_dependent::TestObjects::Biblios::ExampleBiblios;

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

use t::db_dependent::TestObjects::Biblios::BiblioFactory;

=head createTestGroupX

    my $hash_of_records = TestObjects::C4::Biblio::ExampleBiblios::createTestGroup1();

    ##Do stuff with the test group##

    #Remember to delete them after use.
    TestObjects::C4::Biblio::ExampleBiblios::deleteTestGroup1($biblionumbers);
=cut

my @testGroup1Identifiers = ('9519671580', '9519671581', '9519671582', '9519671583',
                            ); #So we can later delete these Biblios
sub createTestGroup1 {
    my @records = [
        {
            "biblio.title"         => 'I wish I met your mother',
            "biblio.author"        => 'Pertti Kurikka',
            "biblio.copyrightdate" => '1960',
            "biblioitems.isbn"     => $testGroup1Identifiers[0],
            "biblioitems.itemtype" => 'BK',
        },
        {
            "biblio.title"         => 'Me and your mother',
            "biblio.author"        => 'Jaakko Kurikka',
            "biblio.copyrightdate" => '1961',
            "biblioitems.isbn"     => $testGroup1Identifiers[1],
            "biblioitems.itemtype" => 'BK',
        },
        {
            "biblio.title"         => 'How I met your mother',
            "biblio.author"        => 'Martti Kurikka',
            "biblio.copyrightdate" => '1962',
            "biblioitems.isbn"     => $testGroup1Identifiers[2],
            "biblioitems.itemtype" => 'DV',
        },
        {
            "biblio.title"         => 'How I wish I had met your mother',
            "biblio.author"        => 'Tapio Kurikka',
            "biblio.copyrightdate" => '1963',
            "biblioitems.isbn"     => $testGroup1Identifiers[3],
            "biblioitems.itemtype" => 'DV',
        },
    ];
    return createTestGroup(\@records);
}
sub deleteTestGroup1 {
    t::db_dependent::TestObjects::Biblios::BiblioFactory::_deleteTestGroupFromIdentifiers(\@testGroup1Identifiers);
}

1;
