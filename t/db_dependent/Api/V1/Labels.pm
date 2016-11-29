package t::db_dependent::Api::V1::Labels;

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

use C4::Labels::SheetManager;

use t::lib::TestObjects::Labels::SheetFactory;

#GET /api/v1/labels/sheets/{sheet_identifier}/{sheet_version} with various responses
sub getsheets_n__n_500 {
    ok(1, "skipped");
}
sub getsheets_n__n_404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $sheet);

    $sheet = t::lib::TestObjects::Labels::SheetFactory->createTestGroup(
                                                   {name => 'Simplex',
                                                   },
                                                    undef, $testContext);
    $sheet = C4::Labels::SheetManager::putNewSheetToDB($sheet);

    #Execute request
    $path = $restTest->get_routePath([$sheet->getId(), $sheet->getVersion()+10]);
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);

    #Compare result
    $driver->json_hasnt('/id', "No Sheet no id");
}
sub getsheets_n__n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $sheet);

    $sheet = t::lib::TestObjects::Labels::SheetFactory->createTestGroup(
                                                   {name => 'Simplex',
                                                   },
                                                    undef, $testContext);
    $sheet = C4::Labels::SheetManager::putNewSheetToDB($sheet);

    #Execute request
    $path = $restTest->get_routePath([$sheet->getId(), $sheet->getVersion()]);
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    #my $json = $driver->tx->res->json();

    #Compare result
    $driver->json_is('/id' =>      $sheet->getId(),      "Sheet id");
    $driver->json_is('/version' => $sheet->getVersion(), "Sheet version");
}
#DELETE /api/v1/labels/sheets/{sheet_identifier}/{sheet_version}
sub deletesheets_n__n_500 {
    ok(1, "skipped");
}
sub deletesheets_n__n_404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $sheet, $sheetFromDB);

    $sheet = t::lib::TestObjects::Labels::SheetFactory->createTestGroup(
                                                   {name => 'Simplex',
                                                   },
                                                    undef, $testContext);
    $sheet = C4::Labels::SheetManager::putNewSheetToDB($sheet);

    #Execute request
    $path = $restTest->get_routePath([$sheet->getId(), $sheet->getVersion()+0.1]);
    $driver->delete_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);

    #Compare result
    $sheetFromDB = C4::Labels::SheetManager::getSheet($sheet->getId(), $sheet->getVersion());
    ok($sheetFromDB, "Request didn't delete anything else");
}
sub deletesheets_n__n_204 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $sheet, $sheetFromDB);

    $sheet = t::lib::TestObjects::Labels::SheetFactory->createTestGroup(
                                                   {name => 'Simplex',
                                                   },
                                                    undef, $testContext);
    $sheet = C4::Labels::SheetManager::putNewSheetToDB($sheet);

    #Execute request
    $path = $restTest->get_routePath([$sheet->getId(), $sheet->getVersion()]);
    $driver->delete_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(204);

    #Compare result
    $sheetFromDB = C4::Labels::SheetManager::getSheet($sheet->getId(), $sheet->getVersion());
    ok(not($sheetFromDB), "Sheet deletion confirmed");
}
sub getsheetsversion500 {
    ok(1, "skipped");
}
sub getsheetsversion404 {
    ok(1, "skipped");
}
sub getsheetsversion200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $sheets, $simplex, $sheetilian, $sheetFromDB);

    $sheets = t::lib::TestObjects::Labels::SheetFactory->createTestGroup([
                                                   {name => 'Simplex',
                                                   },
                                                   {name => 'Sheetilian',
                                                   },
                                                ], undef, $testContext);
    $simplex    = C4::Labels::SheetManager::putNewSheetToDB( $sheets->{'Simplex-0.3'} );
    $sheetilian = C4::Labels::SheetManager::putNewSheetToDB( $sheets->{'Sheetilian-1.2'} );

    $simplex->setVersion( $simplex->getVersion()+0.1 );
    C4::Labels::SheetManager::putNewVersionToDB( $simplex );
    $simplex->setVersion( $simplex->getVersion()+0.1 );
    C4::Labels::SheetManager::putNewVersionToDB( $simplex );

    #Execute request
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    #Compare result
    $driver->json_is('/0/name' => $simplex->getName(),           "Sheet0v3: Name");
    $driver->json_is('/0/version' => $simplex->getVersion(),     "Sheet0v3: Version");
    $driver->json_is('/1/name' => $simplex->getName(),           "Sheet0v2: Name");
    $driver->json_is('/1/version' => $simplex->getVersion()-0.1, "Sheet0v2: Version");
    $driver->json_is('/2/name' => $simplex->getName(),           "Sheet0v1: Name");
    $driver->json_is('/2/version' => $simplex->getVersion()-0.2, "Sheet0v1: Version");
    $driver->json_is('/3/name' => $sheetilian->getName(),        "Sheet1v1: Name");
    $driver->json_is('/3/version' => $sheetilian->getVersion(),  "Sheet1v1: Version");
}
sub putsheets500 {
    ok(1, "skipped");
}
sub putsheets404 {
    ok(1, "skipped");
}
sub putsheets400 {
    ok(1, "skipped");
}
sub putsheets201 {
    ok(1, "skipped");
}
sub postsheets500 {
    ok(1, "skipped");
}
sub postsheets400 {
    ok(1, "skipped");
}
sub postsheets201 {
    ok(1, "skipped");
}
sub getsheets500 {
    ok(1, "skipped");
}
sub getsheets404 {
    ok(1, "skipped");
}
sub getsheets200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $sheet);

    $sheet = t::lib::TestObjects::Labels::SheetFactory->createTestGroup(
                                                   {name => 'Simplex',
                                                   },
                                                    undef, $testContext);
    $sheet = C4::Labels::SheetManager::putNewSheetToDB($sheet);

    #Execute request
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    my $json = $driver->tx->res->json();

    #Compare result
    ok($json->[0] =~ /"Simplex"/, "Sheet name");
    #TODO:: This test-suite leaks label_sheets but I shouldn't be doing this now anyway.
}

1;
