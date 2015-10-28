#!/usr/bin/perl

# Copyright 2015 KohaSuomi
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
use Try::Tiny;
use Scalar::Util qw(blessed);

use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::HoldFactory;
use t::lib::TestObjects::SystemPreferenceFactory;
use Koha::Calendar;

##Setting up the test context
my $testContext = {};
my $calendar = Koha::Calendar->new(branchcode => 'CPL');
$calendar->add_holiday( DateTime->now(time_zone => C4::Context->tz())->subtract(days => 2) ); #Day before yesterday is a holiday.

t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([{preference => 'PickupExpiredHoldsOverReportDuration',
                                                                value => 2,
                                                               },
                                                               {preference => 'ExpireReservesMaxPickUpDelay',
                                                                value => 1,
                                                               },
                                                               {preference => 'ReservesMaxPickUpDelay',
                                                                value => 6,
                                                               },
                                                              ], undef, $testContext);

my $holds = t::lib::TestObjects::HoldFactory->createTestGroup([
            {cardnumber  => '1A01',
             isbn        => '987Kivi',
             barcode     => '1N01',
             branchcode  => 'CPL',
             waitingdate => DateTime->now(time_zone => C4::Context->tz())->subtract(days => 9)->iso8601(),
             reservenotes => 'expire3daysAgo',
            },
            {cardnumber  => '1A01',
             isbn        => '987Kivi',
             barcode     => '1N02',
             branchcode  => 'CPL',
             waitingdate => DateTime->now(time_zone => C4::Context->tz())->subtract(days => 8)->iso8601(),
             reservenotes => 'expire2daysAgo',
            },
            {cardnumber  => '1A02',
             isbn        => '987Kivi',
             barcode     => '1N03',
             branchcode  => 'CPL',
             waitingdate => DateTime->now(time_zone => C4::Context->tz())->subtract(days => 7)->iso8601(),
             reservenotes => 'expire1dayAgo1',
            },
            {cardnumber  => '1A03',
             isbn        => '987Kivi',
             barcode     => '1N04',
             branchcode  => 'CPL',
             waitingdate => DateTime->now(time_zone => C4::Context->tz())->subtract(days => 7)->iso8601(),
             reservenotes => 'expire1dayAgo2',
            },
            {cardnumber  => '1A04',
             isbn        => '987Kivi',
             barcode     => '1N05',
             branchcode  => 'CPL',
             waitingdate => DateTime->now(time_zone => C4::Context->tz())->subtract(days => 6)->iso8601(),
             reservenotes => 'expiresToday',
            },
            {cardnumber  => '1A05',
             isbn        => '987Kivi',
             barcode     => '1N06',
             branchcode  => 'CPL',
             waitingdate => DateTime->now(time_zone => C4::Context->tz())->subtract(days => 5)->iso8601(),
             reservenotes => 'expiresTomorrow',
            },
        ], undef, $testContext);



##Test context set, starting testing:
subtest "Expiring holds and getting old_reserves" => \&expiringHoldsAndOld_reserves;
sub expiringHoldsAndOld_reserves {
    eval { #run in a eval-block so we don't die without tearing down the test context
        C4::Reserves::CancelExpiredReserves();
        my $expiredReserves = C4::Reserves::GetExpiredReserves({branchcode => 'CPL'});
        ok($expiredReserves->[0]->{reserve_id} == $holds->{'expire2daysAgo'}->{reserve_id} &&
           $expiredReserves->[0]->{pickupexpired} eq DateTime->now(time_zone => C4::Context->tz())->subtract(days => 2)->ymd()
           , "Hold for Item 1N02 expired yesterday");
        ok($expiredReserves->[1]->{reserve_id} == $holds->{'expire1dayAgo1'}->{reserve_id} &&
           $expiredReserves->[1]->{pickupexpired} eq DateTime->now(time_zone => C4::Context->tz())->subtract(days => 1)->ymd()
           , "Hold for Item 1N03 expired today");
        ok($expiredReserves->[2]->{reserve_id} == $holds->{'expire1dayAgo2'}->{reserve_id} &&
           $expiredReserves->[2]->{pickupexpired} eq DateTime->now(time_zone => C4::Context->tz())->subtract(days => 1)->ymd()
           , "Hold for Item 1N04 expired today");
        is($expiredReserves->[3], undef,
           "Holds for Items 1N05 and 1N06 not expired.");
    };
    if ($@) { #Catch all leaking errors and gracefully terminate.
        warn $@;
        tearDown();
        exit 1;
    }
}

##All tests done, tear down test context
tearDown();
done_testing;

sub tearDown {
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
}