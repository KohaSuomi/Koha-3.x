package t::db_dependent::TestObjects::Borrowers::ExampleBorrowers;

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

use t::db_dependent::TestObjects::Borrowers::BorrowerFactory;

=head createTestGroupX

    You should use the appropriate Factory-class to create these test-objects.

=cut

my @testGroup1Identifiers = ('167Azel0001', '167Azel0002', '167Azel0003', '167Azel0004',
                             '167Azel0005', '167Azel0006', '167Azel0007', '167Azel0008',
                            );
sub createTestGroup1 {
    my @borrowers = (
        {cardnumber => $testGroup1Identifiers[0], branchcode => 'CPL', categorycode => 'YA',
         surname => 'Costly', firstname => 'Colt', address => 'Street 11', zipcode => '10221'},
        {cardnumber => $testGroup1Identifiers[1], branchcode => 'CPL', categorycode => 'YA',
         surname => 'Dearly', firstname => 'Colt', address => 'Street 12', zipcode => '10222'},
        {cardnumber => $testGroup1Identifiers[2], branchcode => 'CPL', categorycode => 'YA',
         surname => 'Pricy', firstname => 'Colt', address => 'Street 13', zipcode => '10223'},
        {cardnumber => $testGroup1Identifiers[3], branchcode => 'CPL', categorycode => 'YA',
         surname => 'Expensive', firstname => 'Colt', address => 'Street 14', zipcode => '10224'},
        {cardnumber => $testGroup1Identifiers[4], branchcode => 'FTL', categorycode => 'YA',
         surname => 'Cheap', firstname => 'Colt', address => 'Street 15', zipcode => '10225'},
        {cardnumber => $testGroup1Identifiers[5], branchcode => 'FTL', categorycode => 'YA',
         surname => 'Poor', firstname => 'Colt', address => 'Street 16', zipcode => '10226'},
        {cardnumber => $testGroup1Identifiers[6], branchcode => 'FTL', categorycode => 'YA',
         surname => 'Stingy', firstname => 'Colt', address => 'Street 17', zipcode => '10227'},
        {cardnumber => $testGroup1Identifiers[7], branchcode => 'FTL', categorycode => 'YA',
         surname => 'Impoverished', firstname => 'Colt', address => 'Street 18', zipcode => '10228'},
    );
    return t::db_dependent::TestObjects::Borrowers::BorrowerFactory::createTestGroup(\@borrowers);
}
sub deleteTestGroup1 {
    t::db_dependent::TestObjects::Borrowers::BorrowerFactory::_deleteTestGroupFromIdentifiers(\@testGroup1Identifiers);
}

1;