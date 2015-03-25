package t::db_dependent::TestObjects::Borrowers::BorrowerFactory;

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

use C4::Members;

use t::db_dependent::TestObjects::Borrowers::ExampleBorrowers;
use t::db_dependent::TestObjects::ObjectFactory qw(getHashKey);

=head t::db_dependent::TestObjects::Borrowers::BorrowerFactory::createTestGroup( $data [, $hashKey] )
Returns a HASH of borrowers.
The HASH is keyed with the PRIMARY KEY, or the given $hashKey.

See C4::Members::AddMember() for how the table columns need to be given.
=cut

sub createTestGroup {
    my ($objects, $hashKey) = @_;

    my %objects;
    foreach my $object (@$objects) {
        my $borrowernumber = C4::Members::AddMember(%$object);
        #If adding failed, we still get some strange borrowernumber result.
        #Check for sure by finding the real borrower.
        my $borrower = C4::Members::GetMember(cardnumber => $object->{cardnumber});
        unless ($borrower) {
            carp "BorrowerFactory:> No borrower for cardnumber '".$object->{cardnumber}."'";
            next();
        }

        my $key = t::db_dependent::TestObjects::ObjectFactory::getHashKey($borrower, $borrowernumber, $hashKey);

        $objects{$key} = $borrower;
    }
    return \%objects;
}

=head

    my $records = createTestGroup();
    ##Do funky stuff
    deleteTestGroup($records);

Removes the given test group from the DB.

=cut

sub deleteTestGroup {
    my $objects = shift;

    my $schema = Koha::Database->new_schema();
    while( my ($key, $object) = each %$objects) {
        $schema->resultset('Borrower')->find($object->{borrowernumber})->delete();
    }
}
sub _deleteTestGroupFromIdentifiers {
    my $testGroupIdentifiers = shift;

    my $schema = Koha::Database->new_schema();
    foreach my $key (@$testGroupIdentifiers) {
        $schema->resultset('Borrower')->find({"cardnumber" => $key})->delete();
    }
}

sub createTestGroup1 {
    return t::db_dependent::TestObjects::Borrowers::ExampleBorrowers::createTestGroup1();
}
sub deleteTestGroup1 {
    return t::db_dependent::TestObjects::Borrowers::ExampleBorrowers::deleteTestGroup1();
}

1;