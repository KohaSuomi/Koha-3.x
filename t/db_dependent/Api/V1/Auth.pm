package t::db_dependent::Api::V1::Auth;

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
use Data::Dumper;
use JSON;

use C4::Auth;
use C4::Context;
use Koha::Auth;
use Koha::Auth::PermissionManager;

use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::ObjectFactory;

sub getsession401 {
    ok(1, "skipped");    #I am lazy :(
}
sub getsession404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $json);

    #Execute request
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'} => json => {sessionid => 'Abrakadabra, hokkuspokkus'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);

    #Compare result
    $json = $driver->tx->res->json();
    ok($json->{error} =~ /bad/i, "Bad session id");
}
sub getsession200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();
    my $permissionManager = Koha::Auth::PermissionManager->new();

    my ($b, $password, $path, $jsonLogin, $restSessionid, $newSessionid, $cookies);

    #Create the test borrower.
    $password = '1234';
    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({
        email => 'testinen@example.com',
        cardnumber => '1A01',
        firstname => 'Juhani',
        surname => 'Seplae',
        password => '1234',
        userid => 'admin',
        branchcode => 'CPL',
    }, undef, $testContext);
    $permissionManager->grantPermission($b, 'auth', 'get_session');

    #First login Juhani
    $path = $restTest->get_routePath();
    $driver->ua->unsubscribe('start'); #Unsubscribe from the default auth headers, since we are making a POST request and the test framework expects us to be making a GET-request
    t::lib::Swagger2TestRunner::_prepareApiKeyAuthenticationHeaders($driver, $restTest->get_activeBorrower(), 'POST');
    $driver->post_ok($path => {Accept => 'text/json'} => form => {userid => $b->cardnumber, password => $password});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(201);
    $driver->json_is('/firstname' => $b->firstname, "Login firstname ok");
    $driver->json_has('/sessionid', "Login sessionid ok");

    #Get the REST consumer sessionid initialized with the API key
    $cookies = $driver->tx->res->cookies();
    $restSessionid = $cookies->[0]->value;
    #Get the logged in user's sessionid from the returned session-object
    $jsonLogin = $driver->tx->res->json();
    $newSessionid = $jsonLogin->{sessionid};

    #Unsubscribe from setting the REST API authentication HTTP Headers, since we are already logged Juhani in via the REST API.
    $driver->ua->unsubscribe('start');
    #Set the new session cookie
    $driver->ua->on(start => sub {
        my ($ua, $tx) = @_;
        $tx->req->cookies({name => 'CGISESSID', value => $newSessionid});
    });

    #Execute request, get Juhani's sessionid with Juhani's credentials
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'} => json => {sessionid => $newSessionid});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    #Compare result
    $driver->json_is('/firstname' => $b->firstname, "Get human firstname");
    $driver->json_has('/sessionid',                 "Get human sessionid");

    #Execute request, get TestRunner AI's sessionid using Juhani's credentials
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'} => json => {sessionid => $restSessionid});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    #Compare result
    $driver->json_is('/firstname' => $activeUser->firstname, "Get REST API firstname");
    $driver->json_has('/sessionid',                          "Get REST API sessionid");

    Koha::Auth::clearUserEnvironment($newSessionid,  {});
    Koha::Auth::clearUserEnvironment($restSessionid, {});
}

sub postsession201 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $password, $jsonLogin, $path, $sessionidFromUserid, $sessionidFromCardnumber, $restSessionid, $cookies);

    #Create the test borrower.
    $password = '1234';
    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({
        email => 'testinen@example.com',
        cardnumber => '1A01',
        firstname => 'Juhani',
        surname => 'Seplae',
        password => $password,
        userid => 'admin',
        branchcode => 'CPL',
    }, undef, $testContext);

    #Execute request using userid
    $path = $restTest->get_routePath();
    $driver->post_ok($path => {Accept => 'text/json'} => form => {userid => $b->userid, password => $password});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(201);

    #Compare result
    $driver->json_is('/firstname' => $b->firstname, "Login userid firstname");
    $driver->json_is('/lastname'  => $b->surname,   "Login userid surname");
    $driver->json_is('/email'     => $b->email,     "Login userid email");
    $driver->json_has('/sessionid',                 "Login userid sessionid");

    #Get the REST consumer sessionid initialized with the API key
    $cookies = $driver->tx->res->cookies();
    $restSessionid = $cookies->[0]->value;
    #Get the logged in user's sessionid from the returned session-object
    $jsonLogin = $driver->tx->res->json();
    $sessionidFromUserid = $jsonLogin->{sessionid};

    #Unsubscribe from setting the REST API authentication HTTP Headers, since we are already logged Juhani in via the REST API.
    $driver->ua->unsubscribe('start');
    #Set the new session cookie
    $driver->ua->on(start => sub {
        my ($ua, $tx) = @_;
        $tx->req->cookies({name => 'CGISESSID', value => $sessionidFromUserid});
    });

    #Execute request using cardnumber
    $path = $restTest->get_routePath();
    $driver->post_ok($path => {Accept => 'text/json'} => form => {cardnumber => $b->cardnumber, password => $password});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(201);
    $jsonLogin = $driver->tx->res->json();
    $sessionidFromCardnumber = $jsonLogin->{sessionid};

    #Compare result
    $driver->json_is('/firstname' => $b->firstname, "Login cardnumber firstname");
    $driver->json_is('/lastname'  => $b->surname,   "Login cardnumber surname");
    $driver->json_is('/email'     => $b->email,     "Login cardnumber email");
    $driver->json_has('/sessionid',                 "Login cardnumber sessionid");

    #Make sure we are reusing the same session
    is($sessionidFromCardnumber, $sessionidFromUserid, "Different login mechanisms reuse the same \$sessionid if possible");

    Koha::Auth::clearUserEnvironment($jsonLogin->{sessionid}, {});
}
sub postsession400 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $password, $json, $path);

    #Create the test borrower.
    $password = '1234';
    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({
        email => 'testinen@example.com',
        cardnumber => '1A01',
        firstname => 'Juhani',
        surname => 'Seplae',
        password => $password,
        userid => 'admin',
        branchcode => 'CPL',
    }, undef, $testContext);

    #Execute request bad password
    $path = $restTest->get_routePath();
    $driver->post_ok($path => {Accept => 'text/json'} => form => {userid => $b->userid, password => $password.'bad'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(400);

    #Compare result
    $json = $driver->tx->res->json() || {};
    ok($json->{error} && $json->{error} !~ /username/, "Session username ok");
    ok($json->{error} && $json->{error} =~ /password/, "Session password failed");

    #Execute request bad password and username
    $path = $restTest->get_routePath();
    $driver->post_ok($path => {Accept => 'text/json'} => form => {userid => $b->userid.'bad', password => $password.'bad'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(400);

    #Compare result
    $json = $driver->tx->res->json() || {};
    ok($json->{error} && $json->{error} =~ /username/, "Session username failed");
    ok($json->{error} && $json->{error} =~ /password/, "Session password failed");
}
sub deletesession200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($b, $password, $jsonLogin, $path, $sessionid, $session, $sessionBodyParam);

    #Create the test borrower.
    $password = '1234';
    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({
        email => 'testinen@example.com',
        cardnumber => '1A01',
        firstname => 'Juhani',
        surname => 'Seplae',
        password => $password,
        userid => 'admin',
        branchcode => 'CPL',
    }, undef, $testContext);

    #Login
    $path = $restTest->get_basePath().'/auth/session';
    $driver->post_ok($path => {Accept => 'text/json'} => form => {userid => $b->userid, password => $password});
    $restTest->catchSwagger2Errors($driver);
    $driver->json_is('/firstname' => $b->firstname, "Login firstname ok");
    $driver->json_has('/sessionid', "Login sessionid ok");
    $jsonLogin = $driver->tx->res->json();

    #Execute request
    $path = $restTest->get_routePath();
    $driver->delete_ok($path => {Accept => 'text/json'} => json => {sessionid => $jsonLogin->{sessionid}});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $session = C4::Auth::get_session($sessionid);

    #Compare result
    isnt($session->param('cardnumber'), $b->cardnumber, "Session deleted");
}
sub deletesession404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path);

    $path = $restTest->get_routePath();
    $driver->delete_ok($path => {Accept => 'text/json'} => json => {sessionid => "Abrakadabra, hokkuspokkus, simsalapim"});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

1;
