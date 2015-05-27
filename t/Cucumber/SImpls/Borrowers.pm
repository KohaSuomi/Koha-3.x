package SImpls::Borrowers;

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

use Koha::Borrowers;
use Koha::Borrower::Debarments;

use t::db_dependent::TestObjects::Borrowers::BorrowerFactory;

sub addBorrowers {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};
    $S->{borrowers} = {} unless $S->{borrowers};
    $F->{borrowers} = {} unless $F->{borrowers};

    my $borrowers = t::db_dependent::TestObjects::Borrowers::BorrowerFactory::createTestGroup($C->data(),'cardnumber');

    while( my ($key, $borrower) = each %$borrowers) {
        $S->{borrowers}->{ $key } = $borrower;
        $F->{borrowers}->{ $key } = $borrower;
    }
}

sub deleteBorrowers {
    my $C = shift;
    my $F = $C->{stash}->{feature};
    t::db_dependent::TestObjects::Borrowers::BorrowerFactory::deleteTestGroup( $F->{borrowers} );
}

sub checkDebarments {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    my $checks = $C->data(); #Get the checks we need to do.
    ok(($checks && scalar(@$checks) > 0), "You must give checks as the data");

    ##Make sure that there are no trailing Debarments.
    my $schema = Koha::Database->new()->schema();
    my $allDebarmentsCount = $schema->resultset('BorrowerDebarment')->search({})->count();
    is($allDebarmentsCount, scalar(@$checks), "We should have ".scalar(@$checks)." checks for $allDebarmentsCount fines, with no trailing fines.");

    #We need to collect all checks for each borrower, because a single borrower can have multiple checks
    my %checksByBorrower;
    foreach my $check (@$checks) {
        unless ($checksByBorrower{$check->{cardnumber}}) {
            $checksByBorrower{$check->{cardnumber}} = [];
        }
        push( @{$checksByBorrower{$check->{cardnumber}}}, $check );
        #Remove keys not needed in the comparison ahead. Leaving keys not found in the debarment-object will ruin the check.
        delete $check->{cardnumber};
    }

    ##Check that there is a matching Debarment for each given check.
    while( my ($cardnumber, $checks) =  each %checksByBorrower ) {
        my $borrower = Koha::Borrowers->find({cardnumber => $cardnumber});
        die "checkDebarments():> No borrower for cardnumber '$cardnumber'" unless ($cardnumber);
        my $debarments = Koha::Borrower::Debarments::GetDebarments({borrowernumber => $borrower->id()});

        #Check every check against every debarment, if all checks are satisifed from the found debarments, all is fine!
        foreach my $check (@$checks) {
            my $checkOk = 0;
            for (my $i=0 ; $i<@$debarments ; $i++) {
                my $debarment = $debarments->[$i];

                #Iterate all the keys in check, and see if they match the debarment
                my $keysNeedingSuccessfulMatch = scalar(keys(%$check));
                while( my ($key, $value) = each %$check ) {
                    if ($debarment->{$key} eq $check->{$key}) {
                        $keysNeedingSuccessfulMatch--;
                    }
                }
                #This debarment matches this check
                if ($keysNeedingSuccessfulMatch == 0) {
                    splice @$debarments, $i, 1;
                    $i--;
                    $checkOk = 1;
                    last();
                }
            }
            return unless ok($checkOk, "Debarment '".join(', ',join(' => ',each(%$check)))."' found.");
        }
    }
}

1;
