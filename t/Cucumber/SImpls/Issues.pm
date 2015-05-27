package SImpls::Issues;

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

use Modern::Perl;
use Carp;
use Test::More;

use C4::Circulation;
use t::db_dependent::TestObjects::Issues::IssueFactory;

sub addIssues {
    my $C = shift;
    my $homeOrHoldingbranch = shift;
    die "addIssues():> \$homeOrHoldingbranch must be 'homebranch' or 'holdingbranch'" unless ($homeOrHoldingbranch eq 'homebranch' || $homeOrHoldingbranch eq 'holdingbranch');
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    $S->{issues} = {} unless $S->{issues};
    $F->{issues} = {} unless $F->{issues};

    my $issues = t::db_dependent::TestObjects::Issues::IssueFactory::createTestGroup( $C->data(), undef, $homeOrHoldingbranch );

    while( my ($key, $issue) = each %$issues) {
        $S->{issues}->{ $key } = $issue;
        $F->{issues}->{ $key } = $issue;
    }
}

##We cannot use the Koha internal API, because then these would be put to the deleteditems, deletedbiblio, old_issues, ... -tables
#Sometimes the test feature can fail and leave straggler Issues, which prevent proper clean up. So it is better to just
#remove all Issues. These tests should be transitive anyway.
sub deleteAllIssues {
    my $C = shift;
    my $F = $C->{stash}->{feature};
    my $schema = Koha::Database->new()->schema();

    $schema->resultset('Issue')->search({})->delete_all();
    $schema->resultset('OldIssue')->search({})->delete_all();
}

sub checkInIssues {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    my $homeOrHoldingbranch = shift;
    die "checkInAllIssues():> \$homeOrHoldingbranch must be 'homebranch' or 'holdingbranch'" unless ($homeOrHoldingbranch eq 'homebranch' || $homeOrHoldingbranch eq 'holdingbranch');

    if (ref $S->{issues} eq 'HASH') {
        while( my ($key, $issue) = each %{$S->{issues}}) {
            my $is = $S->{issues}->{ $key };
            my ($doreturn, $messages, $iteminformation, $borrower) = C4::Circulation::AddReturn( $is->{barcode}, $is->{branchcode} );
            my $debug; #Just here so I can inspect the AddReturn return values with the DBGP-protocol.
        }
    }
    else {
        die "checkInIssues():> No Scenario HASH for Issues!";
    }
}

1;
