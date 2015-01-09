#!/usr/bin/perl

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
use utf8;

use DateTime;
use C4::Biblio;
use C4::Branch;
use C4::Items;
use C4::Members;
use C4::Reserves;
use Koha::DateUtils;

use Test::More tests => 57;

BEGIN {
    use_ok('C4::Circulation');
}

my $dbh = C4::Context->dbh;

# Start transaction
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

# Start with a clean slate
$dbh->do('DELETE FROM issues');

my $CircControl = C4::Context->preference('CircControl');
my $HomeOrHoldingBranch = C4::Context->preference('HomeOrHoldingBranch');

my $item = {
    homebranch => 'MPL',
    holdingbranch => 'MPL'
};

my $borrower = {
    branchcode => 'MPL'
};

# No userenv, PickupLibrary
C4::Context->set_preference('CircControl', 'PickupLibrary');
is(
    C4::Context->preference('CircControl'),
    'PickupLibrary',
    'CircControl changed to PickupLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $item->{$HomeOrHoldingBranch},
    '_GetCircControlBranch returned item branch (no userenv defined)'
);

# No userenv, PatronLibrary
C4::Context->set_preference('CircControl', 'PatronLibrary');
is(
    C4::Context->preference('CircControl'),
    'PatronLibrary',
    'CircControl changed to PatronLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $borrower->{branchcode},
    '_GetCircControlBranch returned borrower branch'
);

# No userenv, ItemHomeLibrary
C4::Context->set_preference('CircControl', 'ItemHomeLibrary');
is(
    C4::Context->preference('CircControl'),
    'ItemHomeLibrary',
    'CircControl changed to ItemHomeLibrary'
);
is(
    $item->{$HomeOrHoldingBranch},
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    '_GetCircControlBranch returned item branch'
);

# Now, set a userenv
C4::Context->_new_userenv('xxx');
C4::Context::set_userenv(0,0,0,'firstname','surname', 'MPL', 'Midway Public Library', '', '', '');
is(C4::Context->userenv->{branch}, 'MPL', 'userenv set');

# Userenv set, PickupLibrary
C4::Context->set_preference('CircControl', 'PickupLibrary');
is(
    C4::Context->preference('CircControl'),
    'PickupLibrary',
    'CircControl changed to PickupLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    'MPL',
    '_GetCircControlBranch returned current branch'
);

# Userenv set, PatronLibrary
C4::Context->set_preference('CircControl', 'PatronLibrary');
is(
    C4::Context->preference('CircControl'),
    'PatronLibrary',
    'CircControl changed to PatronLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $borrower->{branchcode},
    '_GetCircControlBranch returned borrower branch'
);

# Userenv set, ItemHomeLibrary
C4::Context->set_preference('CircControl', 'ItemHomeLibrary');
is(
    C4::Context->preference('CircControl'),
    'ItemHomeLibrary',
    'CircControl changed to ItemHomeLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $item->{$HomeOrHoldingBranch},
    '_GetCircControlBranch returned item branch'
);

# Reset initial configuration
C4::Context->set_preference('CircControl', $CircControl);
is(
    C4::Context->preference('CircControl'),
    $CircControl,
    'CircControl reset to its initial value'
);

# Set a simple circ policy
$dbh->do('DELETE FROM issuingrules');
$dbh->do(
    q{INSERT INTO issuingrules (categorycode, branchcode, itemtype, reservesallowed,
                                maxissueqty, issuelength, lengthunit,
                                renewalsallowed, renewalperiod,
                                fine, chargeperiod)
      VALUES (?, ?, ?, ?,
              ?, ?, ?,
              ?, ?,
              ?, ?
             )
    },
    {},
    '*', '*', '*', 25,
    20, 14, 'days',
    1, 7,
    .10, 1
);

# Test C4::Circulation::ProcessOfflinePayment
my $sth = C4::Context->dbh->prepare("SELECT COUNT(*) FROM accountlines WHERE amount = '-123.45' AND accounttype = 'Pay'");
$sth->execute();
my ( $original_count ) = $sth->fetchrow_array();

C4::Context->dbh->do("INSERT INTO borrowers ( cardnumber, surname, firstname, categorycode, branchcode ) VALUES ( '99999999999', 'Hall', 'Kyle', 'S', 'MPL' )");

C4::Circulation::ProcessOfflinePayment({ cardnumber => '99999999999', amount => '123.45' });

$sth->execute();
my ( $new_count ) = $sth->fetchrow_array();

ok( $new_count == $original_count  + 1, 'ProcessOfflinePayment makes payment correctly' );

C4::Context->dbh->do("DELETE FROM accountlines WHERE borrowernumber IN ( SELECT borrowernumber FROM borrowers WHERE cardnumber = '99999999999' )");
C4::Context->dbh->do("DELETE FROM borrowers WHERE cardnumber = '99999999999'");
C4::Context->dbh->do("DELETE FROM accountlines");
{
# CanBookBeRenewed tests

    # Generate test biblio
    my $biblio = MARC::Record->new();
    my $title = 'Silence in the library';
    $biblio->append_fields(
        MARC::Field->new('100', ' ', ' ', a => 'Moffat, Steven'),
        MARC::Field->new('245', ' ', ' ', a => $title),
    );

    my ($biblionumber, $biblioitemnumber) = AddBiblio($biblio, '');

    my $barcode = 'R00000342';
    my $branch = 'MPL';

    my ( $item_bibnum, $item_bibitemnum, $itemnumber ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode,
            replacementprice => 12.00
        },
        $biblionumber
    );

    my $barcode2 = 'R00000343';
    my ( $item_bibnum2, $item_bibitemnum2, $itemnumber2 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode2,
            replacementprice => 23.00
        },
        $biblionumber
    );

    my $barcode3 = 'R00000346';
    my ( $item_bibnum3, $item_bibitemnum3, $itemnumber3 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode3,
            replacementprice => 23.00
        },
        $biblionumber
    );

    # Create 2 borrowers
    my %renewing_borrower_data = (
        firstname =>  'John',
        surname => 'Renewal',
        categorycode => 'S',
        branchcode => $branch,
    );

    my %reserving_borrower_data = (
        firstname =>  'Katrin',
        surname => 'Reservation',
        categorycode => 'S',
        branchcode => $branch,
    );

    my $renewing_borrowernumber = AddMember(%renewing_borrower_data);
    my $reserving_borrowernumber = AddMember(%reserving_borrower_data);

    my $renewing_borrower = GetMember( borrowernumber => $renewing_borrowernumber );

    my $constraint     = 'a';
    my $bibitems       = '';
    my $priority       = '1';
    my $resdate        = undef;
    my $expdate        = undef;
    my $notes          = '';
    my $checkitem      = undef;
    my $found          = undef;

    my $datedue = AddIssue( $renewing_borrower, $barcode);
    is (defined $datedue, 1, "Item 1 checked out, due date: $datedue");

    my $datedue2 = AddIssue( $renewing_borrower, $barcode2);
    is (defined $datedue2, 1, "Item 2 checked out, due date: $datedue2");

    my $borrowing_borrowernumber = GetItemIssue($itemnumber)->{borrowernumber};
    is ($borrowing_borrowernumber, $renewing_borrowernumber, "Item checked out to $renewing_borrower->{firstname} $renewing_borrower->{surname}");

    my ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber, 1);
    is( $renewokay, 1, 'Can renew, no holds for this title or item');


    # Biblio-level hold, renewal test
    AddReserve(
        $branch, $reserving_borrowernumber, $biblionumber,
        $constraint, $bibitems,  $priority, $resdate, $expdate, $notes,
        $title, $checkitem, $found
    );

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 0, '(Bug 10663) Cannot renew, reserved');
    is( $error, 'on_reserve', '(Bug 10663) Cannot renew, reserved (returned error is on_reserve)');

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber2);
    is( $renewokay, 0, '(Bug 10663) Cannot renew, reserved');
    is( $error, 'on_reserve', '(Bug 10663) Cannot renew, reserved (returned error is on_reserve)');

    my $reserveid = C4::Reserves::GetReserveId({ biblionumber => $biblionumber, borrowernumber => $reserving_borrowernumber});
    my $reserving_borrower = GetMember( borrowernumber => $reserving_borrowernumber );
    AddIssue($reserving_borrower, $barcode3);
    my $reserve = $dbh->selectrow_hashref(
        'SELECT * FROM old_reserves WHERE reserve_id = ?',
        { Slice => {} },
        $reserveid
    );
    is($reserve->{found}, 'F', 'hold marked completed when checking out item that fills it');

    # Item-level hold, renewal test
    AddReserve(
        $branch, $reserving_borrowernumber, $biblionumber,
        $constraint, $bibitems,  $priority, $resdate, $expdate, $notes,
        $title, $itemnumber, $found
    );

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber, 1);
    is( $renewokay, 0, '(Bug 10663) Cannot renew, item reserved');
    is( $error, 'on_reserve', '(Bug 10663) Cannot renew, item reserved (returned error is on_reserve)');

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber2, 1);
    is( $renewokay, 1, 'Can renew item 2, item-level hold is on item 1');


    # Items can't fill hold for reasons
    ModItem({ notforloan => 1 }, $biblionumber, $itemnumber);
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber, 1);
    is( $renewokay, 1, 'Can renew, item is marked not for loan, hold does not block');
    ModItem({ notforloan => 0, itype => '' }, $biblionumber, $itemnumber,1);

    # FIXME: Add more for itemtype not for loan etc.

    $reserveid = C4::Reserves::GetReserveId({ biblionumber => $biblionumber, itemnumber => $itemnumber, borrowernumber => $reserving_borrowernumber});
    CancelReserve({ reserve_id => $reserveid });

    # set policy to require that loans cannot be
    # renewed until seven days prior to the due date
    $dbh->do('UPDATE issuingrules SET norenewalbefore = 7');
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 0, 'Cannot renew, renewal is premature');
    is( $error, 'too_soon', 'Cannot renew, renewal is premature (returned code is too_soon)');
    is(
        GetSoonestRenewDate($renewing_borrowernumber, $itemnumber),
        $datedue->clone->add(days => -7),
        'renewals permitted 7 days before due date, as expected',
    );

    # Too many renewals

    # set policy to forbid renewals
    $dbh->do('UPDATE issuingrules SET norenewalbefore = NULL, renewalsallowed = 0');

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 0, 'Cannot renew, 0 renewals allowed');
    is( $error, 'too_many', 'Cannot renew, 0 renewals allowed (returned code is too_many)');

    # Test WhenLostForgiveFine and WhenLostChargeReplacementFee
    C4::Context->set_preference('WhenLostForgiveFine','1');
    C4::Context->set_preference('WhenLostChargeReplacementFee','1');

    C4::Overdues::UpdateFine( $itemnumber, $renewing_borrower->{borrowernumber},
        15.00, q{}, Koha::DateUtils::output_pref($datedue) );

    LostItem( $itemnumber, 1 );

    my $total_due = $dbh->selectrow_array(
        'SELECT SUM( amountoutstanding ) FROM accountlines WHERE borrowernumber = ?',
        undef, $renewing_borrower->{borrowernumber}
    );

    ok( $total_due == 12, 'Borrower only charged replacement fee with both WhenLostForgiveFine and WhenLostChargeReplacementFee enabled' );

    C4::Context->dbh->do("DELETE FROM accountlines");

    C4::Context->set_preference('WhenLostForgiveFine','0');
    C4::Context->set_preference('WhenLostChargeReplacementFee','0');

    C4::Overdues::UpdateFine( $itemnumber2, $renewing_borrower->{borrowernumber},
        15.00, q{}, Koha::DateUtils::output_pref($datedue) );

    LostItem( $itemnumber2, 1 );

    $total_due = $dbh->selectrow_array(
        'SELECT SUM( amountoutstanding ) FROM accountlines WHERE borrowernumber = ?',
        undef, $renewing_borrower->{borrowernumber}
    );

    ok( $total_due == 15, 'Borrower only charged fine with both WhenLostForgiveFine and WhenLostChargeReplacementFee disabled' );

    my $now = dt_from_string();
    my $future = dt_from_string();
    $future->add( days => 7 );
    my $units = C4::Overdues::_get_chargeable_units('days', $future, $now, 'MPL');
    ok( $units == 0, '_get_chargeable_units returns 0 for items not past due date (Bug 12596)' );
}

{
    # GetUpcomingDueIssues tests
    my $barcode  = 'R00000342';
    my $barcode2 = 'R00000343';
    my $barcode3 = 'R00000344';
    my $branch   = 'MPL';

    #Create another record
    my $biblio2 = MARC::Record->new();
    my $title2 = 'Something is worng here';
    $biblio2->append_fields(
        MARC::Field->new('100', ' ', ' ', a => 'Anonymous'),
        MARC::Field->new('245', ' ', ' ', a => $title2),
    );
    my ($biblionumber2, $biblioitemnumber2) = AddBiblio($biblio2, '');

    #Create third item
    AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode3
        },
        $biblionumber2
    );

    # Create a borrower
    my %a_borrower_data = (
        firstname =>  'Fridolyn',
        surname => 'SOMERS',
        categorycode => 'S',
        branchcode => $branch,
    );

    my $a_borrower_borrowernumber = AddMember(%a_borrower_data);
    my $a_borrower = GetMember( borrowernumber => $a_borrower_borrowernumber );

    my $yesterday = DateTime->today(time_zone => C4::Context->tz())->add( days => -1 );
    my $two_days_ahead = DateTime->today(time_zone => C4::Context->tz())->add( days => 2 );
    my $today = DateTime->today(time_zone => C4::Context->tz());

    my $datedue  = AddIssue( $a_borrower, $barcode, $yesterday );
    my $datedue2 = AddIssue( $a_borrower, $barcode2, $two_days_ahead );

    my $upcoming_dues;

    # GetUpcomingDueIssues tests
    for my $i(0..1) {
        $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => $i } );
        is ( scalar( @$upcoming_dues ), 0, "No items due in less than one day ($i days in advance)" );
    }

    #days_in_advance needs to be inclusive, so 1 matches items due tomorrow, 0 items due today etc.
    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 2 } );
    is ( scalar ( @$upcoming_dues), 1, "Only one item due in 2 days or less" );

    for my $i(3..5) {
        $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => $i } );
        is ( scalar( @$upcoming_dues ), 1,
            "Bug 9362: Only one item due in more than 2 days ($i days in advance)" );
    }

    # Bug 11218 - Due notices not generated - GetUpcomingDueIssues needs to select due today items as well

    my $datedue3 = AddIssue( $a_borrower, $barcode3, $today );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => -1 } );
    is ( scalar ( @$upcoming_dues), 0, "Overdues can not be selected" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 0 } );
    is ( scalar ( @$upcoming_dues), 1, "1 item is due today" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 1 } );
    is ( scalar ( @$upcoming_dues), 1, "1 item is due today, none tomorrow" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 2 }  );
    is ( scalar ( @$upcoming_dues), 2, "2 items are due withing 2 days" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 3 } );
    is ( scalar ( @$upcoming_dues), 2, "2 items are due withing 2 days" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues();
    is ( scalar ( @$upcoming_dues), 2, "days_in_advance is 7 in GetUpcomingDueIssues if not provided" );

}

##Preparing test Objects for the testReturnToShelvingCart() because none are available in this context.
##The test can be easily moved to another context.
#Create another record
my $biblio = MARC::Record->new();
$biblio->append_fields(
    MARC::Field->new('100', ' ', ' ', a => 'The Anonymous'),
    MARC::Field->new('245', ' ', ' ', a => 'Something is worng here')
);
my ($biblionumber, $biblioitemnumber, $itemnumber) = C4::Biblio::AddBiblio($biblio, '');
$biblio = C4::Biblio::GetBiblio($biblionumber);
#Create any circulable item
($biblionumber, $biblioitemnumber, $itemnumber) = C4::Items::AddItem(
    {
        homebranch       => 'CPL',
        holdingbranch    => 'CPL',
        barcode          => 'SauliNiinistö',
    },
    $biblionumber
);
$item = C4::Items::GetItem($itemnumber);
# Create a borrower
my $borrowernumber = C4::Members::AddMember(
    firstname =>  'Fridolyn',
    surname => 'SOMERS',
    categorycode => 'S',
    branchcode => 'CPL',
);
$borrower = C4::Members::GetMember(borrowernumber => $borrowernumber);
testReturnToShelvingCart($borrower, $item);

$dbh->rollback;

1;

=head testReturnToShelvingCart

    testReturnToShelvingCart($borrower, $item);

    Runs 8 tests for the ReturnToShelvingCart-feature.

@PARAM1, borrower-hash from koha.borrowers-table, can be any Borrower who can check-out/in
@PARAM2, item-hash from koha-items-table, can be any Item which can be circulated

=cut
sub testReturnToShelvingCart {
    my $borrower = shift; #Any borrower who can check-in-out will do.
    my $item = shift; #Any Item that can be circulated will do.
    my $originalIssues = C4::Circulation::GetIssues({borrowernumber => $borrower->{borrowernumber}});
    my $originalReturnToShelvingCart = C4::Context->preference('ReturnToShelvingCart'); #Store the original preference so we can rollback changes
    C4::Context->set_preference('ReturnToShelvingCart', 1) unless $originalReturnToShelvingCart; #Make sure it is 'Move'

    #TEST1: Make sure the Item has an intelligible location and permanent_location
    my $location = 'BOOK';
    my $anotherLocation = 'SHELF';
    C4::Items::ModItem({location => $location}, $item->{biblionumber}, $item->{itemnumber});
    $item = C4::Items::GetItem($item->{itemnumber}); #Update the DB changes.
    ok($item->{permanent_location} eq $location, "ReturnToShelvingCart: Setting a proper location succeeded.");

    #TEST2: It makes no difference in which state the Item is, when it is returned, the location changes to 'CART'
    C4::Circulation::AddReturn($item->{barcode}, $borrower->{branchcode});
    $item = C4::Items::GetItem($item->{itemnumber}); #Update the DB changes.
    ok($item->{permanent_location} eq $location && $item->{location} eq 'CART', "ReturnToShelvingCart: Item returned, location and permanent_location OK!");

    #TEST3: Editing the Item didn't screw up the permanent_location
    C4::Items::ModItem({price => 12}, $item->{biblionumber}, $item->{itemnumber});
    $item = C4::Items::GetItem($item->{itemnumber}); #Update the DB changes.
    ok($item->{permanent_location} eq $location && $item->{location} eq 'CART', "ReturnToShelvingCart: Minor modifying an Item doesn't overwrite permanent_location!");

    #TEST4: Checking an Item out to test another possible state.
    C4::Items::ModItem({location => $location}, $item->{biblionumber}, $item->{itemnumber}); #Reset the original location, as if the cart_to_Shelf.pl-script has been ran.
    C4::Circulation::AddIssue($borrower, $item->{barcode});
    my $issues = C4::Circulation::GetIssues({borrowernumber => $borrower->{borrowernumber}});
    ok(  scalar(@$originalIssues)+1 == scalar(@$issues)  ,"ReturnToShelvingCart: Adding an Issue succeeded!"  );

    #TEST5:
    C4::Circulation::AddReturn($item->{barcode}, $borrower->{branchcode});
    $item = C4::Items::GetItem($item->{itemnumber}); #Update the DB changes.
    ok($item->{permanent_location} eq $location && $item->{location} eq 'CART', "ReturnToShelvingCart: Item returned again, location and permanent_location OK!");

    #TEST6: Editing the Item without a permanent_location
    #  (like when Editing the item using the staff clients editing view @ additem.pl?biblionumber=469263)
    #  didn't screw up the permanent_location
    delete $item->{permanent_location};
    C4::Items::ModItem($item, $item->{biblionumber}, $item->{itemnumber});
    $item = C4::Items::GetItem($item->{itemnumber}); #Update the DB changes.
    ok($item->{permanent_location} eq $location && $item->{location} eq 'CART', "ReturnToShelvingCart: Modifying the whole Item doesn't overwrite permanent_location!");

    #TEST7: Modifying only the permanent_location is an interesting option! So our Item is in 'CART', but we want to keep it there (hypothetically) and change the real location!
    C4::Items::ModItem({permanent_location => $anotherLocation}, $item->{biblionumber}, $item->{itemnumber});
    $item = C4::Items::GetItem($item->{itemnumber}); #Update the DB changes.
    ok($item->{permanent_location} eq $anotherLocation && $item->{location} eq 'CART', "ReturnToShelvingCart: Modifying the permanent_location while the location is 'CART'.");

    #TEST8: Adding an Item without a permanent_location defined... Justin Case
    my $yetAnotherLocation = 'STAFF';
    my ( $xyz4lol, $whysomany4, $addedItemnumber ) = C4::Items::AddItem(
        {
            location         => $yetAnotherLocation,
            homebranch       => 'CPL',
            holdingbranch    => 'MPL',
            barcode          => 'Hölökyn kölökyn',
            replacementprice => 16.00
        },
        $item->{biblionumber}
    );
    my $addedItem = C4::Items::GetItem($addedItemnumber);
    ok($item->{permanent_location} eq $yetAnotherLocation && $item->{location} eq $yetAnotherLocation, "ReturnToShelvingCart: Adding a new Item with location also sets the permanent_location.");

    C4::Context->set_preference('ReturnToShelvingCart', $originalReturnToShelvingCart) unless $originalReturnToShelvingCart; #Set it to the original value
}
