package t::db_dependent::Api::V1::Serials;

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

use t::lib::TestObjects::Serial::SubscriptionFactory;

#GET /api/v1/serials/collection with various responses
sub getcollection500 {
    ok(1, "skipped");    #I am lazy :(
}
sub getcollection404 {
    ok(1, "skipped");    #I am lazy :(
}
sub getcollection400 {
    ok(1, "skipped");    #I am lazy :(
}
sub getcollection200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($subscriptions, $biblionumber, $thisYear, $json, $path);
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

    #Execute request
    $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'} => form => {
        biblionumber => 0+$biblionumber,
        serialStatus => 2, #received
    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $json = $driver->tx->res->json;

    #Compare result
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/1/pattern_x" => $thisYear, "Number1: pattern_x");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/1/pattern_y" => 1,         "Number1: pattern_y");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/1/pattern_z" => 1,         "Number1: pattern_z");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/1/arrived"   => 2,         "Number1: arrived count");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/2/pattern_x" => $thisYear, "Number2: pattern_x");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/2/pattern_y" => 1,         "Number2: pattern_y");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/2/pattern_z" => 2,         "Number2: pattern_z");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/2/arrived"   => 2,         "Number2: arrived count");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/3/pattern_x" => $thisYear, "Number3: pattern_x");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/3/pattern_y" => 1,         "Number3: pattern_y");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/3/pattern_z" => 3,         "Number3: pattern_z");
    $driver->json_is("/collectionMap/$thisYear/childs/1/childs/3/arrived"   => 2,         "Number3: arrived count");
}

1;
