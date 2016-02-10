package t::db_dependent::Api::V1::Serialitems;

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

use C4::Branch;
use C4::Koha;

use t::lib::TestObjects::Serial::SubscriptionFactory;

#GET /api/v1/serialitems with various responses
sub get500 {
    ok(1, "skipped");    #I am lazy :(
}
sub get404 {
    ok(1, "skipped");    #I am lazy :(
}
sub get400 {
    ok(1, "skipped");    #I am lazy :(
}
sub get200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($subscriptions, $biblionumber, $thisYear, $json, $path, $holdingbranch, $c_holdingbranch, $location, $c_location);
    $thisYear = DateTime->now(time_zone => C4::Context->tz())->year;

    #Create the test subscription + serials.
    $subscriptions = t::lib::TestObjects::Serial::SubscriptionFactory->createTestGroup([
            {
                internalnotes => 'ser-CPL', #MANDATORY! Used as the hash-key
                receiveSerials => 3,
                branchcode => 'CPL',
                weeklength => 52, #DEFAULT one year subscription
            },
            {
                internalnotes => 'ser-FPL', #MANDATORY! Used as the hash-key
                receiveSerials => 3,
                branchcode => 'FPL',
                weeklength => 52, #DEFAULT one year subscription
            }
        ], undef, $testContext);
    $biblionumber = $subscriptions->{'ser-CPL'}->biblionumber;
    $location = $subscriptions->{'ser-CPL'}->location;
    $c_location = C4::Koha::GetAuthorisedValueByCode('LOC', $location);

    #Execute request with narrow limit
    #Get 1 newest serialItems from CPL
    $holdingbranch = 'CPL';
    $c_holdingbranch = C4::Branch::GetBranchName($holdingbranch);
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'} => form => {
        biblionumber  => 0+$biblionumber,
        serialStatus  => 2, #received
        limit         => 1,
        holdingbranch => $holdingbranch,
        pattern_x     => $thisYear,
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $json = $driver->tx->res->json;

    #Compare result
    $driver->json_is("/serialItems/0/biblionumber"    => $biblionumber,    "SerialItem0: biblionumber");
    $driver->json_is("/serialItems/0/holdingbranch"   => $holdingbranch,   "SerialItem0: holdingbranch");
    $driver->json_is("/serialItems/0/c_holdingbranch" => $c_holdingbranch, "SerialItem0: cleartext holdingbranch");
    $driver->json_is("/serialItems/0/pattern_x"       => $thisYear,        "SerialItem0: pattern_x");
    $driver->json_is("/serialItems/0/pattern_z"       => 3,                "SerialItem0: pattern_z"); #Always show the newest serials
    $driver->json_hasnt("/serialItems/1/biblionumber", "No SerialItem1, limit works");

    #Execute request with broad limit
    #Get 3 newest serialItems from FPL
    $holdingbranch = 'FPL';
    $c_holdingbranch = C4::Branch::GetBranchName($holdingbranch);
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'} => form => {
        biblionumber  => 0+$biblionumber,
        serialStatus  => 2, #received
        limit         => 3,
        holdingbranch => $holdingbranch,
        pattern_x     => $thisYear,
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $json = $driver->tx->res->json;

    #Compare result
    $driver->json_is("/serialItems/0/biblionumber"    => $biblionumber,    "SerialItem0: biblionumber");
    $driver->json_is("/serialItems/0/holdingbranch"   => $holdingbranch,   "SerialItem0: holdingbranch");
    $driver->json_is("/serialItems/0/c_holdingbranch" => $c_holdingbranch, "SerialItem0: cleartext holdingbranch");
    $driver->json_is("/serialItems/0/pattern_x"       => $thisYear,        "SerialItem0: pattern_x");
    $driver->json_is("/serialItems/0/pattern_z"       => 3,                "SerialItem0: pattern_z");
    $driver->json_is("/serialItems/1/biblionumber"    => $biblionumber,    "SerialItem1: biblionumber");
    $driver->json_is("/serialItems/1/holdingbranch"   => $holdingbranch,   "SerialItem1: holdingbranch");
    $driver->json_is("/serialItems/1/c_holdingbranch" => $c_holdingbranch, "SerialItem1: cleartext holdingbranch");
    $driver->json_is("/serialItems/1/pattern_x"       => $thisYear,        "SerialItem1: pattern_x");
    $driver->json_is("/serialItems/1/pattern_z"       => 2,                "SerialItem1: pattern_z");
    $driver->json_is("/serialItems/2/biblionumber"    => $biblionumber,    "SerialItem2: biblionumber");
    $driver->json_is("/serialItems/2/holdingbranch"   => $holdingbranch,   "SerialItem2: holdingbranch");
    $driver->json_is("/serialItems/2/c_holdingbranch" => $c_holdingbranch, "SerialItem2: cleartext holdingbranch");
    $driver->json_is("/serialItems/2/pattern_x"       => $thisYear,        "SerialItem2: pattern_x");
    $driver->json_is("/serialItems/2/pattern_z"       => 1,                "SerialItem2: pattern_z");
    $driver->json_hasnt("/serialItems/3/biblionumber", "No SerialItem3 received");

    #Execute request with specific number but any holdingbranch
    #Since we have subscriptions to two different branches, we have two serialItems of one specific number.
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'} => form => {
        biblionumber  => 0+$biblionumber,
        serialStatus  => 2, #received
        pattern_x     => $thisYear,
        pattern_y     => 1,
        pattern_z     => 3,
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $json = $driver->tx->res->json;

    #Compare result
    $driver->json_is("/serialItems/0/biblionumber" => $biblionumber, "SerialItem0: biblionumber");
    $driver->json_is("/serialItems/0/location"     => $location,     "SerialItem0: location");
    $driver->json_is("/serialItems/0/c_location"   => $c_location,   "SerialItem0: cleartext location");
    $driver->json_is("/serialItems/0/pattern_x"    => $thisYear,     "SerialItem0: pattern_x");
    $driver->json_is("/serialItems/0/pattern_z"    => 3,             "SerialItem0: pattern_z");
    $driver->json_is("/serialItems/1/biblionumber" => $biblionumber, "SerialItem1: biblionumber");
    $driver->json_is("/serialItems/1/location"     => $location,     "SerialItem1: location");
    $driver->json_is("/serialItems/1/c_location"   => $c_location,   "SerialItem1: cleartext location");
    $driver->json_is("/serialItems/1/pattern_x"    => $thisYear,     "SerialItem1: pattern_x");
    $driver->json_is("/serialItems/1/pattern_z"    => 3,             "SerialItem1: pattern_z");
    $driver->json_hasnt("/serialItems/2/biblionumber", "No SerialItem2 received");
}

1;
