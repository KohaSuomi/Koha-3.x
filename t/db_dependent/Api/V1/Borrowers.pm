package t::db_dependent::Api::V1::Borrowers;

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
use Mojo::Parameters;

use t::lib::Mojo;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::HoldFactory;
use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::BiblioFactory;
use t::lib::TestObjects::ItemFactory;
use t::lib::TestObjects::SystemPreferenceFactory;
use t::db_dependent::opening_hours_context;

#GET /borrowers/{borrowernumber}, with response 200

sub get_n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    #Create the test borrower.
    my $b = [{ cardnumber => '11A01', firstname => 'Olli', surname => 'Kiivi', password => '1234', userid => 'admin', branchcode => 'CPL' }];
    my $borrowers = t::lib::TestObjects::BorrowerFactory->createTestGroup($b, undef, $testContext, undef, undef);
    $b = $borrowers->{'11A01'};
    my $borrowernumber = $b->borrowernumber;

    #Execute request
    my $path = $restTest->get_routePath($borrowernumber);
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    #Compare result
    $driver->json_is('/borrowernumber' => $borrowernumber, "Got the same borrower '$borrowernumber'");
}

sub get_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    #Create the test borrower and get the borrowernumber. We know for sure that this borrowernumber is not already in use.
    my $b = [{ cardnumber => '11A01', firstname => 'Olli', surname => 'Kiivi', password => '1234', userid => 'admin', branchcode => 'CPL' }];
    my $borrowers = t::lib::TestObjects::BorrowerFactory->createTestGroup($b, undef, $testContext, undef, undef);
    $b = $borrowers->{'11A01'};
    my $borrowernumber = $b->borrowernumber;

    #Delete the borrower so we can no longer find it.
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);

    #Make the HTTP request
    my $path = $restTest->get_routePath($borrowernumber);
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

#GET /borrowers, with response 200

sub get200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($borrowers, $b, $b1, $b2);

    #Make the HTTP request
    my $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $driver->json_has('email', 'Got something meaningful');

    ## ## Test GETting by biblionumber, userid, cardnumber ##
    $b = [{ cardnumber => '11A01', firstname => 'Olli',  surname => 'Kiivi', password => '1234', userid => 'admin' },
          { cardnumber => '11A02', firstname => 'Hillo', surname => 'Iivik', password => '1234', userid => 'nidam' },
          { cardnumber => '11A03', firstname => 'Halla', surname => 'Ilari', password => '1234', userid => 'maind' }];
    $borrowers = t::lib::TestObjects::BorrowerFactory->createTestGroup($b, undef, $testContext, undef, undef);
    ## GET with biblionumber
    $b = $borrowers->{'11A01'};
    $driver->get_ok($path => {Accept => '*/*'} => form => {borrowernumber => 0+$b->borrowernumber});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $driver->json_is('/0/cardnumber' => $b->cardnumber, "Got the correct borrower with borrowernumber");
    ## GET with cardnumber
    $b = $borrowers->{'11A02'};
    $driver->get_ok($path => {Accept => '*/*'} => form => {cardnumber => $b->cardnumber});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $driver->json_is('/0/firstname' => $b->firstname, "Got the correct borrower with cardnumber");
    ## GET with userid
    $b = $borrowers->{'11A03'};
    $driver->get_ok($path => {Accept => '*/*'} => form => {userid => $b->userid});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $driver->json_is('/0/cardnumber' => $b->cardnumber, "Got the correct borrower with userid");
    ## GET with cardnumber and userid
    $b1 = $borrowers->{'11A01'};
    $b2 = $borrowers->{'11A02'};
    $driver->get_ok($path => {Accept => '*/*'} => form => {cardnumber => $b1->cardnumber, userid => $b2->userid});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $driver->json_is('/0/firstname' => $b1->firstname, "Got the first borrower with cardnumber");
    $driver->json_is('/1/firstname' => $b2->firstname, "Got the second borrower with userid");
}

#/api/v1/borrowers/{borrowernumber}/holds
sub post_n_holds500 {
    my ($class, $restTest, $driver) = @_;
    #I am lazy :(
    ok(1, "skipped");
}
#/api/v1/borrowers/{borrowernumber}/holds'
sub post_n_holds404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($borrowernumber, $path);

    #Place a hold for a user that doesn't exist
    $path = $restTest->get_routePath(999999999);
    $driver->post_ok($path => {Accept => '*/*'} => json => {
        biblionumber => 999999999,
        branchcode => 'CPL'
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
    $driver->json_like('/error' => qr/borrower/i, "404: No such borrower");


    #Place a hold for a biblio which doesn't exist
    $borrowernumber = $activeUser->{borrowernumber} || $activeUser->borrowernumber;
    $path = $restTest->get_routePath($borrowernumber);
    $driver->post_ok($path => {Accept => '*/*'} => json => {
        biblionumber => 999999999,
        branchcode => 'CPL'
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
    $driver->json_like('/error' => qr/biblio/i, "404: No such biblio");
}
sub post_n_holds403 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($borrower, $biblio, $path, $json);

    $borrower = t::lib::TestObjects::BorrowerFactory->createTestGroup(
        {   cardnumber => '11A01',
            password => '1234'
        }, undef, $testContext
    );
    $biblio = t::lib::TestObjects::BiblioFactory->createTestGroup(
        {   'biblioitems.isbn'  => '971-how-I-met-your-mother',
            'biblio.title' => 'How I want your mother'
        }, undef, $testContext
    );

    #Place a hold
    $path = $restTest->get_routePath( $borrower->borrowernumber );
    $driver->post_ok($path => {Accept => '*/*'} => json => {
        biblionumber => 0+$biblio->{biblionumber},
        branchcode => 'CPL'
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(403);
    $json = $driver->tx->res->json;
    #Test result
    ok($json->{error} =~ /noItems/i, "Cannot place a Hold because of no Items");
}
sub post_n_holds400 {
    ok(1, "skipped");
}
sub post_n_holds201 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($biblio, $path, $item, $dbh);

    $biblio = t::lib::TestObjects::BiblioFactory->createTestGroup(
        {   'biblioitems.isbn'  => '971-how-I-want-your-mother',
            'biblio.title' => 'How I met your mother'
        }, undef, $testContext
    );
    $item = t::lib::TestObjects::ItemFactory->createTestGroup(
        {   barcode => '1N007',
            biblionumber  => $biblio->{biblionumber},
        }
    );
    #A VERY UGLY HACK to allow placing holds. Since the issuingrules-table has no CRUD accessors this is what must be done before those accessors are added.
    C4::Context->dbh()->do("INSERT INTO `issuingrules` VALUES ('*','*',NULL,0.000000,NULL,0.250000,0,0,1,NULL,NULL,100,28,'days',NULL,-1,5,28,NULL,20,'*',5.000000)");

    #Place a hold
    $path = $restTest->get_routePath( $activeUser->borrowernumber );
    $driver->post_ok($path => {Accept => '*/*'} => json => {
        biblionumber => 0+$biblio->{biblionumber},
        branchcode => 'CPL'
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(201);
    $driver->json_is('/biblionumber'   => $biblio->{biblionumber},     "Hold biblionumber");
    $driver->json_is('/borrowernumber' => $activeUser->borrowernumber, "Hold borrowernumber");
    $driver->json_has('/reserve_id',                                   "Hold reserve_id");
    $driver->json_is('/branchcode'     => $activeUser->branchcode,     "Hold branchcode");

    #Place a Item-level hold
    $path = $restTest->get_routePath( $activeUser->borrowernumber );
    $driver->post_ok($path => {Accept => '*/*'} => json => {
        biblionumber => 0+$biblio->{biblionumber},
        itemnumber => 0+$item->itemnumber,
        branchcode => 'CPL'
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(201);
    $driver->json_is('/biblionumber'   => $biblio->{biblionumber},     "Hold biblionumber");
    $driver->json_is('/itemnumber'     => $item->itemnumber,           "Hold itemnumber");
    $driver->json_is('/borrowernumber' => $activeUser->borrowernumber, "Hold borrowernumber");
    $driver->json_has('/reserve_id',                                   "Hold reserve_id");
    $driver->json_is('/branchcode'     => $activeUser->branchcode,     "Hold branchcode");

    #Get rid of garbage
    C4::Context->dbh()->do("DELETE FROM `issuingrules` LIMIT 1");
}
sub get_n_holds404 {
    ok(1, "skipped");
}
sub get_n_holds200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $borrowernumber, $holds, $path);

    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup(
        {   cardnumber => '11A01',
            password => '1234'
    }, undef, $testContext, undef, undef);
    $holds = t::lib::TestObjects::HoldFactory->createTestGroup( [
        {
            cardnumber        => $b->cardnumber,
            isbn              => '971040323123', #ISBN of the Biblio, even if the record normally doesn't have a ISBN, you must mock one on it.
            barcode           => '1N01',    #Item's barcode, if this is an Item-level hold.
            branchcode        => 'FPL',
            waitingdate       => '2015-01-15', #Since when has this hold been waiting for pickup?
            reservenotes      => 'res1', #Default identifier column to identify this individual Hold
        },
        {
            cardnumber        => $b->cardnumber,
            isbn              => '971040323124', #ISBN of the Biblio, even if the record normally doesn't have a ISBN, you must mock one on it.
            branchcode        => 'IPT',
            reservenotes      => 'res2', #Default identifier column to identify this individual Hold
        },
    ], undef, $testContext);

    $borrowernumber = $b->borrowernumber;
    $path = $restTest->get_routePath($borrowernumber);
    $driver->get_ok($path => {Accept => '*/*'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $driver->json_is('/0/branchcode' => 'FPL', "1st Hold");
    $driver->json_is('/1/branchcode' => 'IPT', "2nd Hold");
}

sub getstatus400 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $path, $ua, $tx, $json);

    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup(
                    {   cardnumber => '11A01',
                        password => '1234'
                    }, undef, $testContext, undef, undef);

    $path = $restTest->get_routePath();

    #Make a custom GET request with formData parameters :) Mojo-fu!
    $ua = $driver->ua;
    $tx = $ua->build_tx(GET => $path => {Accept => '*/*'});
    $tx->req->body( Mojo::Parameters->new("uname=".$b->cardnumber."&passwd=4321")->to_string);
    $tx->req->headers->remove('Content-Type');
    $tx->req->headers->add('Content-Type' => 'application/x-www-form-urlencoded');
    $tx = $ua->start($tx);
    $restTest->catchSwagger2Errors($tx);
    $json = $tx->res->json;
    is($tx->res->code, 400, "Bad credentials given, got response");
    is(ref($json), 'HASH', "Got a json-object");
    ok($json && $json->{error} && $json->{error} =~ /password/i, "Password authentication failed");
}

sub getstatus200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $path, $ua, $tx, $json);

    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup(
                    {   cardnumber => '11A01',
                        password => '1234'
                    }, undef, $testContext, undef, undef);

    $path = $restTest->get_routePath();
    #Make a custom GET request with formData parameters :) Mojo-fu!
    $ua = $driver->ua;
    $tx = $ua->build_tx(GET => $path => {Accept => '*/*'});
    $tx->req->body( Mojo::Parameters->new("uname=".$b->cardnumber."&passwd=1234")->to_string);
    $tx->req->headers->remove('Content-Type');
    $tx->req->headers->add('Content-Type' => 'application/x-www-form-urlencoded');
    $tx = $ua->start($tx);
    $restTest->catchSwagger2Errors($tx);
    $json = $tx->res->json;
    is($tx->res->code, 200, "Good credentials given");
    is(ref($json), 'HASH', "Got a json-object");
    is($json->{cardnumber}, $b->cardnumber, "Got a borrower!");
}

sub getssstatus404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $path, $ua, $tx, $json);

    ##Make sure there is no such member
    $b = C4::Members::GetMember(cardnumber => '11A01');
    C4::Members::DelMember($b->{borrowernumber}) if $b;

    $path = $restTest->get_routePath();

    $tx = t::lib::Mojo::getWithFormData($driver, $restTest->get_routePath(), {cardnumber => "11A01"});
    $restTest->catchSwagger2Errors($tx);
    $json = $tx->res->json;
    is($tx->res->code, 404, "No such cardnumber 404");
    is(ref($json), 'HASH', "Got a json-object");
    ok($json && $json->{error} && $json->{error} =~ /cardnumber/i, "No such cardnumber text");
}

sub getssstatus200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $path, $ua, $tx, $json);

    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup(
                    {   cardnumber => '11A01',
                        password => '1234'
                    }, undef, $testContext, undef, undef);

    t::db_dependent::opening_hours_context::createContext($testContext);

    $path = $restTest->get_routePath();

    my $getssstatus200_tac_fail = sub {
        $tx = t::lib::Mojo::getWithFormData($driver, $restTest->get_routePath(), {cardnumber => "11A01"});
        $restTest->catchSwagger2Errors($tx);
        $json = $tx->res->json;
        is($tx->res->code, 200, "Good barcode given");
        is(ref($json), 'HASH', "Got a json-object");
        is($json->{permission}, '0', "Permission denied!");
        is($json->{error}, 'Koha::Exception::SelfService::TACNotAccepted', "Exception class correct!");
    };
    subtest "Fail because terms and conditions are not accepted", $getssstatus200_tac_fail;

    my $getssstatus200_tac_accepted = sub {
        ##Accept terms and conditions
        C4::Members::Attributes::SetBorrowerAttributes($b->borrowernumber, [{ code => 'SST&C', value => '1' }]);
        $tx = t::lib::Mojo::getWithFormData($driver, $restTest->get_routePath(), {cardnumber => "11A01"});
        $restTest->catchSwagger2Errors($tx);
        $json = $tx->res->json;
        is($tx->res->code, 200, "Good barcode given");
        is(ref($json), 'HASH', "Got a json-object");
        is($json->{permission}, '1', "Permission granted!");
    };
    subtest "Succeed because terms and conditions were accepted", $getssstatus200_tac_accepted;

    my $getssstatus200_library_closed = sub {
        $tx = t::lib::Mojo::getWithFormData($driver, $restTest->get_routePath(), {cardnumber => "11A01", branchcode => 'MPL'});
        $restTest->catchSwagger2Errors($tx);
        $json = $tx->res->json;
        is($tx->res->code, 200, "Good barcode given");
        is(ref($json), 'HASH', "Got a json-object");
        is($json->{permission}, '0', "Permission denied!");
        is($json->{error},     'Koha::Exception::SelfService::OpeningHours', "Exception class correct!");
        like($json->{startTime}, qr/\d\d:\d\d/, "startTime of correct format");
        like($json->{endTime},   qr/\d\d:\d\d/, "endTime of correct format");
    };
    subtest "Fail because library MPL is closed", $getssstatus200_library_closed;

}

sub getssstatus500 {
    ok(1, "skipped");
}

sub getssstatus501 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $tx, $json);

    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup(
                    {   cardnumber => '11A01',
                        password => '1234'
                    }, undef, $testContext, undef, undef);

    t::lib::TestObjects::SystemPreferenceFactory->createTestGroup({
                        preference => 'SSRules',
                        value => '',
                    }, undef, $testContext);

    $tx = t::lib::Mojo::getWithFormData($driver, $restTest->get_routePath(), {cardnumber => "11A01"});
    $restTest->catchSwagger2Errors($tx);
    $json = $tx->res->json;
    is($tx->res->code, 501, "501 - Feature misconfigured");
    is(ref($json), 'HASH', "Got a json-object");
    ok($json && $json->{error} && $json->{error} =~ /SSRules/, "Feature unavailable");
}

1;
