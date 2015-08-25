#!/usr/bin/perl

# Copyright 2015 Open Source Freedom Fighters
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
use Try::Tiny; #Even Selenium::Remote::Driver uses Try::Tiny :)
use Scalar::Util qw(blessed);

use t::lib::Page::Members::Statistics;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::CheckoutFactory;
use Koha::Auth::PermissionManager;

$ENV{KOHA_PAGEOBJECT_DEBUG} = 1;

subtest "Show Borrower Statistics" => \&showBorrowerStatistics;
sub showBorrowerStatistics {
    ##Setting up the test context
    my $subtestContext = {};

    eval { #run in a eval-block so we don't die without tearing down the test context
    ##Create the test Borrower
    my $password = '1234';
    my $borrowerFactory = t::lib::TestObjects::BorrowerFactory->new();
    my $borrowers = $borrowerFactory->createTestGroup(
                            {cardnumber => '1A01',
                             branchcode => 'CPL',
                             userid     => 'mini_admin',
                             password   => $password,
                            },
                            , undef, $subtestContext);
    my $permissionManager = Koha::Auth::PermissionManager->new();
    $permissionManager->grantPermissions($borrowers->{'1A01'}, {borrowers => 'view_borrowers',});

    ##Test context set, starting testing:
    my $statistics = t::lib::Page::Members::Statistics->new({borrowernumber => $borrowers->{'1A01'}->borrowernumber});
    $statistics->doPasswordLogin($borrowers->{'1A01'}->userid, $password)->isStatisticsRows([]); #We shouldn't have any statistics

    ##Checkout two Items
    my $checkouts = t::lib::TestObjects::CheckoutFactory->createTestGroup(
                            [   {barcode => 'Item021T',
                                 cardnumber => '1A01',
                                },
                                {barcode => 'Item022T',
                                 cardnumber => '1A01',
                                },
                            ],
                            undef, $subtestContext);

    ##We should have one statistics row.
    $statistics->refresh()->isStatisticsRows([{todaysCheckouts => 2}]);

    };
    if ($@) { #Catch all leaking errors and gracefully terminate.
        warn $@;
    }
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);
}

done_testing;
