package t::db_dependent::Api::V1::Biblios;

# Copyright 2016 KohaSuomi
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Test::More;

use t::lib::TestObjects::BiblioFactory;
use t::lib::TestObjects::ItemFactory;
use t::lib::TestObjects::ObjectFactory;

sub delete_n_204 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $biblio, $biblionumber, $record);

    #Create the test context.
    $biblio = t::lib::TestObjects::BiblioFactory->createTestGroup(
                        {'biblio.title' => 'The significant chore of building test faculties',
                         'biblio.author'   => 'Programmer, Broken',
                         'biblio.copyrightdate' => '2015',
                         'biblioitems.isbn'     => '951967151337',
                         'biblioitems.itemtype' => 'BK',
                        }, undef, $testContext);
    $biblionumber = $biblio->{biblionumber};

    #Execute request
    $path = $restTest->get_routePath($biblionumber);
    $driver->delete_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(204);

    #Confirm result
    $record = C4::Biblio::GetBiblio( $biblio->{biblionumber} );
    ok(not($record), "Biblio deletion confirmed");
}

sub delete_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $biblio, $biblionumber, $record);

    #Create the test context.
    $biblio = t::lib::TestObjects::BiblioFactory->createTestGroup(
                        {'biblio.title' => 'The significant chore of building test faculties',
                         'biblio.author'   => 'Programmer, Broken',
                         'biblio.copyrightdate' => '2015',
                         'biblioitems.isbn'     => '951967151337',
                         'biblioitems.itemtype' => 'BK',
                        }, undef, $testContext);
    $biblionumber = $biblio->{biblionumber};
    C4::Biblio::DelBiblio($biblionumber);
    #Now we have a biblionumber which certainly doesn't exists!

    #Execute request
    $path = $restTest->get_routePath($biblionumber);
    $driver->delete_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub delete_n_400 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $biblio, $biblionumber, $record, $item);

    #Create the test context.
    $biblio = t::lib::TestObjects::BiblioFactory->createTestGroup(
                        {'biblio.title' => 'The significant chore of building test faculties',
                         'biblio.author'   => 'Programmer, Broken',
                         'biblio.copyrightdate' => '2015',
                         'biblioitems.isbn'     => '951967151337',
                         'biblioitems.itemtype' => 'BK',
                        }, undef, $testContext);
    $biblionumber = $biblio->{biblionumber};
    $item = t::lib::TestObjects::ItemFactory->createTestGroup(
                                {biblionumber => $biblionumber,
                                 barcode => '11N01'}
                                , undef, $testContext);

    #Execute request
    $path = $restTest->get_routePath($biblionumber);
    $driver->delete_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(400);

    #Confirm result
    $record = C4::Biblio::GetBiblio( $biblio->{biblionumber} );
    ok($record, "Biblio deletion aborted due to attached Items");
}

1;
