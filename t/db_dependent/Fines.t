#!/usr/bin/perl

# Copyright 2015 Vaara-kirjastot
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

use C4::Accounts;

use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::BorrowerFactory;

##Setting up the test context
my $testContext = {};

my $password = '1234';
my $borrowerFactory = t::lib::TestObjects::BorrowerFactory->new();
my $borrowers = $borrowerFactory->createTestGroup([
            {firstname  => 'Olli-Antti',
             surname    => 'Kivi',
             cardnumber => '1A01',
             branchcode => 'CPL',
             password   => $password,
            },
            {firstname  => 'Alli-Ontti',
             surname    => 'Ivik',
             cardnumber => '1A02',
             branchcode => 'CPL',
             password   => $password,
            },
            {firstname  => 'NoFines',
             surname    => 'Angel',
             cardnumber => '1A03',
             branchcode => 'CPL',
             password   => $password,
            },
        ], undef, $testContext);

##Test context set, starting testing:
subtest "Get all Borrowers with Fines" => \&getAllBorrowersWithFines;
sub getAllBorrowersWithFines {
    eval { #run in a eval-block so we don't die without tearing down the test context
    my $borrowerKivi = $borrowers->{'1A01'};
    my $borrowerIvik = $borrowers->{'1A02'};

    #What happens if there are only good Borrowers?
    my $badBorrowers = C4::Accounts::GetAllBorrowersWithUnpaidFines();
    ok(ref($badBorrowers) eq 'ARRAY',
       "GetAllBorrowersWithUnpaidFines, no results is still an ARRAYRef");

    C4::Accounts::manualinvoice($borrowerKivi->borrowernumber, undef, 'TESTIS1', 'F', 1.123456, 'NOTED');
    C4::Accounts::manualinvoice($borrowerKivi->borrowernumber, undef, 'TESTIS2', 'F', 2, 'NOTED');
    C4::Accounts::manualinvoice($borrowerKivi->borrowernumber, undef, 'TESTIS3', 'F', 3, 'NOTED');
    C4::Accounts::manualinvoice($borrowerIvik->borrowernumber, undef, 'TESTIS1', 'F', 1.123456, 'NOTED');
    C4::Accounts::manualinvoice($borrowerIvik->borrowernumber, undef, 'TESTIS2', 'F', 2, 'NOTED');
    C4::Accounts::manualinvoice($borrowerIvik->borrowernumber, undef, 'TESTIS3', 'F', 3, 'NOTED');
    C4::Accounts::manualinvoice($borrowerIvik->borrowernumber, undef, 'TESTIS4', 'F', 4, 'NOTED');

    $badBorrowers = C4::Accounts::GetAllBorrowersWithUnpaidFines();
    is($borrowerKivi->cardnumber,
       $badBorrowers->[0]->{cardnumber},
       "Got the correct bad Borrower '".$borrowerKivi->cardnumber."'");
    is($badBorrowers->[0]->{amountoutstanding},
       6.123456,
       "Got the correct unpaid fines '6'");
    is($borrowerIvik->cardnumber,
       $badBorrowers->[1]->{cardnumber},
       "Got the correct bad Borrower '".$borrowerIvik->cardnumber."'");
    is($badBorrowers->[1]->{amountoutstanding},
       10.123456,
       "Got the correct unpaid fines '10'");
    ok(not(defined($badBorrowers->[2])),
       "Good Borrower not on the bad Borrowers list");

    };
    if ($@) { #Catch all leaking errors and gracefully terminate.
        ok(0, $@);
    }
}

##All tests done, tear down test context
tearDown();
done_testing;

sub tearDown {
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
}