package t::db_dependent::TestObjects::Issues::IssueFactory;

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

use C4::Circulation;
use C4::Members;
use C4::Items;

use t::db_dependent::TestObjects::Issues::ExampleIssues;
use t::db_dependent::TestObjects::ObjectFactory;

=head t::db_dependent::TestObjects::Issues::IssueFactory::createTestGroup( $data [, $hashKey, $checkoutBranchRule] )
Returns a Issues-HASH.
The HASH is keyed with the PRIMARY KEY, or the given $hashKey.

@PARAM1, ARRAY of HASHes.
  [ {
        cardnumber  => '167Azava0001',
        barcode     => '167Nfafa0010',
        daysOverdue => 7,     #This issue's duedate was 7 days ago. If undef, then uses today as the checkout day.
        daysAgoIssued  => 28, #This Issue hapened 28 days ago. If undef, then uses today.
    },
    {
        ...
    }
  ]
@PARAM2, String, the HASH-element to use as the returning HASHes key.
@PARAM3, String, the rule on where to check these Issues out:
                 'homebranch', uses the Item's homebranch as the checkout branch
                 'holdingbranch', uses the Item's holdingbranch as the checkout branch
                 undef, uses the current Environment branch
                 '<branchCode>', checks out all Issues from the given branchCode
=cut

sub createTestGroup {
    my ($objects, $hashKey, $checkoutBranchRule) = @_;

    my $oldContextBranch = C4::Context->userenv()->{branch};

    my %objects;
    foreach my $issueParams (@$objects) {
        my $borrower = C4::Members::GetMember(cardnumber => $issueParams->{cardnumber});
        my $item = C4::Items::GetItem(undef, $issueParams->{barcode});

        my $duedate = DateTime->now(time_zone => C4::Context->tz());
        if ($issueParams->{daysOverdue}) {
            $duedate->subtract(days =>  $issueParams->{daysOverdue}  );
        }

        my $issuedate = DateTime->now(time_zone => C4::Context->tz());
        if ($issueParams->{daysAgoIssued}) {
            $issuedate->subtract(days =>  $issueParams->{daysAgoIssued}  );
        }

        #Set the checkout branch
        my $checkoutBranch;
        if (not($checkoutBranchRule)) {
            #Use the existing userenv()->{branch}
        }
        elsif ($checkoutBranchRule eq 'homebranch') {
            $checkoutBranch = $item->{homebranch};
        }
        elsif ($checkoutBranchRule eq 'holdingbranch') {
            $checkoutBranch = $item->{holdingbranch};
        }
        elsif ($checkoutBranchRule) {
            $checkoutBranch = $checkoutBranchRule;
        }
        C4::Context->userenv()->{branch} = $checkoutBranch if $checkoutBranch;

        my $datedue = C4::Circulation::AddIssue( $borrower, $issueParams->{barcode}, $duedate, undef, $issuedate );
        #We want the issue_id as well.
        my $issues = C4::Circulation::GetIssues({ borrowernumber => $borrower->{borrowernumber}, itemnumber => $item->{itemnumber} });
        my $issue = $issues->[0];
        unless ($issue) {
            carp "IssueFactory:> No issue for cardnumber '".$issueParams->{cardnumber}."' and barcode '".$issueParams->{barcode}."'";
            next();
        }

        my $key = t::db_dependent::TestObjects::ObjectFactory::getHashKey($issue, $issue->{issue_id}, $hashKey);

        $issue->{barcode} = $issueParams->{barcode}; #Save the barcode here as well for convenience.
        $objects{$key} = $issue;
    }

    C4::Context->userenv()->{branch} = $oldContextBranch;
    return \%objects;
}

=head

    my $objects = createTestGroup();
    ##Do funky stuff
    deleteTestGroup($records);

Removes the given test group from the DB.

=cut

sub deleteTestGroup {
    my $objects = shift;

    my $schema = Koha::Database->new_schema();
    while( my ($key, $object) = each %$objects) {
        $schema->resultset('Issue')->find($object->{issue_id})->delete();
    }
}
sub _deleteTestGroupFromIdentifiers {
    my $testGroupIdentifiers = shift;

    my $schema = Koha::Database->new_schema();
    foreach my $key (@$testGroupIdentifiers) {
        $schema->resultset('Issue')->find({"barcode" => $key})->delete();
    }
}

sub createTestGroup1 {
    return t::db_dependent::TestObjects::Issues::ExampleIssues::createTestGroup1();
}
sub deleteTestGroup1 {
    return t::db_dependent::TestObjects::Issues::ExampleIssues::deleteTestGroup1();
}

1;
