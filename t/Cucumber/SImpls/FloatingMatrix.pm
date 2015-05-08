package SImpls::FloatingMatrix;

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

use Try::Tiny;
use Scalar::Util qw(blessed);

use Koha::FloatingMatrix;
use Koha::FloatingMatrix::BranchRule;
use C4::Items;

sub addFloatingMatrixRules {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    $S->{floatingMatrixRules} = {} unless $S->{floatingMatrixRules};
    $F->{floatingMatrixRules} = {} unless $F->{floatingMatrixRules};

    my $fm = Koha::FloatingMatrix->new();

    for (my $i=0 ; $i<scalar(@{$C->data()}) ; $i++) {
        my $hash = $C->data()->[$i];
        my $key = $hash->{fromBranch}.'-'.$hash->{toBranch};
        my $fmRule = Koha::FloatingMatrix::BranchRule->new($hash);
        $fm->upsertBranchRule($fmRule);

        $S->{floatingMatrixRules}->{ $key } = $fmRule;
        $F->{floatingMatrixRules}->{ $key } = $fmRule;
    }
    $fm->store();
}

sub deleteAllFloatingMatrixRules {
    my $fm = Koha::FloatingMatrix->new();
    $fm->deleteAllFloatingMatrixRules();
}

sub checkFloatingMatrixRules {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    my $floatingMatrixRules = $S->{floatingMatrixRules};

    if ($floatingMatrixRules && ref $floatingMatrixRules eq 'HASH') {
        my $fm = Koha::FloatingMatrix->new();
        foreach my $key (keys %$floatingMatrixRules) {
            my $fmbr = $floatingMatrixRules->{$key};
            if (blessed $fmbr && $fmbr->isa('Koha::FloatingMatrix::BranchRule')) {
                my $newFmbr = $fm->getBranchRule($fmbr->getFromBranch(), $fmbr->getToBranch());

                #Delete the id from the DB-representation, so we can compare them with the id-less test object.
                my $storedId = $fmbr->getId(); #Store the id so we wont lose it from the scenario/feature stashes
                $fmbr->setId(undef);
                $newFmbr->setId(undef);

                my $ok = is_deeply($fmbr, $newFmbr, "FloatingMatrixRule fromBranch '".$fmbr->getFromBranch()."' toBranch '".$fmbr->getToBranch."' found deeply");
                $fmbr->setId($storedId); #Restore the id after comparison.
                $newFmbr->setId($storedId);
                last unless $ok;

                #Delete branch rule from the Koha::FloatingMatrix internal mapping,
                # but not from the DB. Change is reverted next time FloatingMatrix is loaded from Koha::Cache
                # This way we ensure we don't accidentally match the same rule twice.
                $fm->deleteBranchRule($fmbr);
            }
            else {
                last unless ok(0, "Test object is not a 'Koha::FloatingMatrix::BranchRule'");
            }
        }
    }
}

sub When_I_ve_deleted_Floating_matrix_rules_then_cannot_find_them {
    my ($C) = shift;
    my $S = $C->{stash}->{scenario};

    my $fm = Koha::FloatingMatrix->new();

    #1. Make sure the rule we are deleting actually exists first
    #2. Delete the rules from FloatingMatrix internal mapping.
    #3. UPDATE deletion to DB.
    #4. Refresh FloatingMatrix
    #5. Check that Rules are really deleted.

    for (my $i=0 ; $i<scalar(@{$C->data()}) ; $i++) {
        my $hash = $C->data()->[$i];

        my $existingBranchRule = $fm->getBranchRule($hash->{fromBranch}, $hash->{toBranch});
        ok(($existingBranchRule && blessed $existingBranchRule && $existingBranchRule->isa('Koha::FloatingMatrix::BranchRule')),
            "A branchRule for fromBranch '".$hash->{fromBranch}."' toBranch '".$hash->{toBranch}."' exists before deletion");

        $fm->deleteBranchRule($existingBranchRule);
        $existingBranchRule = $fm->getBranchRule($hash->{fromBranch}, $hash->{toBranch});
        ok((not($existingBranchRule)),
            "A branchRule for fromBranch '".$hash->{fromBranch}."' toBranch '".$hash->{toBranch}."' deleted from internal map");
    }
    $fm->store(); #update deletion to DB

    $fm = Koha::FloatingMatrix->new();
    
    for (my $i=0 ; $i<scalar(@{$C->data()}) ; $i++) {
        my $hash = $C->data()->[$i];

        my $existingBranchRule = $fm->getBranchRule($hash->{fromBranch}, $hash->{toBranch});
        ok((not($existingBranchRule)),
            "A branchRule for fromBranch '".$hash->{fromBranch}."' toBranch '".$hash->{toBranch}."' deleted from DB");
    }
}

sub When_I_try_to_add_Floating_matrix_rules_with_bad_values_I_get_errors {
    my ($C) = shift;
    my $data = $C->data();

    my $fm = Koha::FloatingMatrix->new();

    my $error = '';
    foreach my $dataElem (@$data) {
        try {
            my $branchRule = $fm->upsertBranchRule($dataElem);
        } catch {
            if (blessed($_)){
                if ($_->isa('Koha::Exception::BadParameter')) {
                    $error = $_->error;
                }
                else {
                    $_->rethrow();
                }
            }
            else {
                die $_;
            }
        };

        my $es = $dataElem->{errorString};
        last unless ok($error =~ /\Q$es\E/, "Adding a bad overdueRule failed. Expecting '$error' to contain '$es'.");
    }
}

=head When_test_given_Items_floats_then_see_status

$C->data() must contain columns
  barcode - the Barcode of the Item we are checking for floating
  fromBranch - branchcode, from which branch we initiate transfer (typically the check-in branch)
  toBranch - branchcode, where we would transfer this Item should we initiate a transfer
  floatCheck - one of the floatin_matrix.floating enumerations.
               To skip testing the given test data-row, use one of the following floatChecks:
                   no_rule  - no floating matrix rule defined for the route, so on floating
                   same_branch - no floating
                   fail_condition - CONDITIONAL floating failed because the logical expression from 'conditionRules' returned false.
=cut

sub When_test_given_Items_floats_then_see_status {
    my ($C) = shift;
    my $checks = $C->data(); #Get the checks, which might not have manifested itselves to the branchtransfers
    ok(($checks && scalar(@$checks) > 0), "You must give checks as the data");

    #See which checks are supposed to be execute, and which are just to clarify intent.
    my @checksInTable;
    foreach my $check (@$checks) {
        my $status = $check->{floatCheck};
        push @checksInTable, $check if ($status ne 'fail_condition' && $status ne 'same_branch' && $status ne 'no_rule');
    }

    my $fm = Koha::FloatingMatrix->new();

    ##Check that we get the expected floating value for each test.
    foreach my $check (@checksInTable) {
        my $item = C4::Items::GetItem(undef, $check->{barcode});
        my $floatType = $fm->checkFloating($item, $check->{fromBranch}, $check->{toBranch});

        last unless ok(($floatType eq $check->{floatCheck}), "Adding a bad overdueRule failed. Expecting '$floatType', got '".$check->{floatCheck}."'.");
    }
}

1;
