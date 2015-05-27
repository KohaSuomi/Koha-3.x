package SImpls::BranchTransfers;

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
use C4::Context;
use C4::Items;
use C4::Circulation;

sub verifyItemsInTransit {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};
    my $checks = $C->data(); #Get the checks, which might not have manifested itselves to the branchtransfers
    ok(($checks && scalar(@$checks) > 0), "You must give checks as the data");

    #See which checks are supposed to be in the branchtransfers-table, and which are just to clarify intent.
    my @checksInTable;
    foreach my $check (@$checks) {
        my $status = $check->{status};
        push @checksInTable, $check if (not($status) || ($status ne 'no_trfr'));
    }

    ##Check that there is a matching branchtransfer-row for each given test.
    my %testedBranchtransfers; #Collect the branchtransfers here so we can see that we won't accidentally test the same transfer twice,
                               # and can tell which branchtransfers are left untested and shouldn't exist according to the test plan.
    foreach my $check (@checksInTable) {
        my @params; #DEL THIS
        my $itemnumber = C4::Items::GetItemnumberFromBarcode( $check->{barcode} );
        my @transfer = C4::Circulation::GetTransfers($itemnumber);
        ##See if the branchtransfer_id is already tested and fail the test, or add the branchtransfer to the tested group.
         #    Throw an failed test only if the test should fail, don't clutter with meaningless tests.
        ok((0), "Not testing fromBranch '".$check->{fromBranch}."', toBranch '".$check->{toBranch}."' twice. Awsum!")
                if(defined($testedBranchtransfers{$transfer[3]}));
        $testedBranchtransfers{$transfer[3]} = \@transfer; #Store the branchtransfer by id

        last unless ok(($transfer[1] eq $check->{fromBranch} && $transfer[2] eq $check->{toBranch}), "Check: fromBranch '".$check->{fromBranch}."', toBranch '".$check->{toBranch}."'");
    }

    ##!# Check for leaking branchtransfers, eg. unintended side-effects.  #!##
    #Remove all tested branchtransfers from all the transfers in DB, and see if we have some more in the DB. This means that our tests leak branchtransfers we didn't intend to have!
    my $allBranchtransfers = C4::Circulation::GetAllTransfers();
    while (my ($branchtransfer_id, $branchtransferArr) = each(%testedBranchtransfers)) {
        for (my $i=0 ; $i<scalar(@$allBranchtransfers) ; $i++) {
            my $branchTransfer = $allBranchtransfers->[$i];
            if ($branchTransfer->{branchtransfer_id} == $branchtransferArr->[3]) { #If id's match, this branchtransfer is tested.
                splice(@$allBranchtransfers, $i, 1); #Remove array element at position $i
                last;
            }
        }
    }
    #Throw a failed tests for each excess branchtransfer encountered. We never get into this loop if tests work ok.
    foreach my $branchTransfer (@$allBranchtransfers) {
        my $item = C4::Items::GetItem(  $branchTransfer->{itemnumber}  );
        ok((not($branchTransfer)), "Trailing branchtransfer for barcode '".$item->{barcode}."' fromBranch '".$branchTransfer->{frombranch}."' toBranch '".$branchTransfer->{tobranch}."'");
    }
}

##We cannot use the Koha internal API, because then these would be preserved as arrived transfers
#Sometimes the test feature can fail and leave straggler Transfers, which prevent proper clean up. So it is better to just
#remove all Transfers. These tests should be transitive anyway.
sub deleteAllTransfers {
    my $C = shift;
    my $F = $C->{stash}->{feature};
    my $schema = Koha::Database->new()->schema();

    $schema->resultset('Branchtransfer')->search({})->delete_all();
}
1;
