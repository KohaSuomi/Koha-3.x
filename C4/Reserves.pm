package C4::Reserves;

# Copyright 2000-2002 Katipo Communications
#           2006 SAN Ouest Provence
#           2007-2010 BibLibre Paul POULAIN
#           2011 Catalyst IT
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


use strict;
#use warnings; FIXME - Bug 2505
use C4::Context;
use C4::Biblio;
use C4::Members;
use C4::Items;
use C4::Circulation;
use C4::Accounts;

# for _koha_notify_reserve
use C4::Members::Messaging;
use C4::Members qw();
use C4::Letters;
use C4::Branch qw( GetBranchDetail );
use C4::Dates qw( format_date_in_iso );

use Koha::DateUtils;
use Koha::Calendar;

use DateTime;
use DateTime::Format::RFC3339;
use DateTime::Format::MySQL;

use List::MoreUtils qw( firstidx );
use Scalar::Util qw(blessed);

use Koha::Exception::BadParameter;
use Koha::Exception::DB;
use Koha::Exception::NoPermission;
use Koha::Exception::UnknownObject;
use Data::Dumper;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

=head1 NAME

C4::Reserves - Koha functions for dealing with reservation.

=head1 SYNOPSIS

  use C4::Reserves;

=head1 DESCRIPTION

This modules provides somes functions to deal with reservations.

  Reserves are stored in reserves table.
  The following columns contains important values :
  - priority >0      : then the reserve is at 1st stage, and not yet affected to any item.
             =0      : then the reserve is being dealed
  - found : NULL       : means the patron requested the 1st available, and we haven't choosen the item
            T(ransit)  : the reserve is linked to an item but is in transit to the pickup branch
            W(aiting)  : the reserve is linked to an item, is at the pickup branch, and is waiting on the hold shelf
            F(inished) : the reserve has been completed, and is done
  - itemnumber : empty : the reserve is still unaffected to an item
                 filled: the reserve is attached to an item
  The complete workflow is :
  ==== 1st use case ====
  patron request a document, 1st available :                      P >0, F=NULL, I=NULL
  a library having it run "transfertodo", and clic on the list    
         if there is no transfer to do, the reserve waiting
         patron can pick it up                                    P =0, F=W,    I=filled 
         if there is a transfer to do, write in branchtransfer    P =0, F=T,    I=filled
           The pickup library recieve the book, it check in       P =0, F=W,    I=filled
  The patron borrow the book                                      P =0, F=F,    I=filled
  
  ==== 2nd use case ====
  patron requests a document, a given item,
    If pickup is holding branch                                   P =0, F=W,   I=filled
    If transfer needed, write in branchtransfer                   P =0, F=T,    I=filled
        The pickup library receive the book, it checks it in      P =0, F=W,    I=filled
  The patron borrow the book                                      P =0, F=F,    I=filled

=head1 FUNCTIONS

=cut

BEGIN {
    # set the version for version checking
    $VERSION = 3.07.00.049;
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw(
        &AddReserve

        &GetReserve
        &GetReservesFromItemnumber
        &GetReservesFromBiblionumber
        &GetReservesFromBorrowernumber
        &GetReservesForBranch
        &GetReservesToBranch
        &GetReserveCount
        &GetReserveFee
        &GetReserveInfo
        &GetReserveStatus
        
        &GetOtherReserves
        
        &ModReserveFill
        &ModReserveAffect
        &ModReserve
        &ModReserveStatus
        &ModReserveCancelAll
        &ModReserveMinusPriority
        &MoveReserve
        
        &CheckReserves
        &CanBookBeReserved
	&CanItemBeReserved
        &CanReserveBeCanceledFromOpac
        &CancelReserve
        &CancelExpiredReserves

        &AutoUnsuspendReserves

        &IsAvailableForItemLevelRequest
        
        &AlterPriority
        &ToggleLowestPriority

        &ReserveSlip
        &ToggleSuspend
        &SuspendAll

        &_reserve_last_pickup_date

        &GetReservesControlBranch
	&CalculatePriority
	&_FixPriority
    );
    @EXPORT_OK = qw( MergeHolds );
}    

=head2 AddReserve

    AddReserve($branch,$borrowernumber,$biblionumber,$constraint,$bibitems,$priority,$resdate,$expdate,$notes,$title,$checkitem,$found)

=cut

sub AddReserve {
    my (
        $branch,    $borrowernumber, $biblionumber,
        $constraint, $bibitems,  $priority, $resdate, $expdate, $notes,
        $title,      $checkitem, $found
    ) = @_;
    my $fee =
          GetReserveFee($borrowernumber, $biblionumber, $constraint,
            $bibitems );
    my $dbh     = C4::Context->dbh;
    my $const   = lc substr( $constraint, 0, 1 );
    $resdate = format_date_in_iso( $resdate ) if ( $resdate );
    $resdate = C4::Dates->today( 'iso' ) unless ( $resdate );
    if ($expdate) {
        $expdate = format_date_in_iso( $expdate );
    } else {
        undef $expdate; # make reserves.expirationdate default to null rather than '0000-00-00'
    }
    if ( C4::Context->preference( 'AllowHoldDateInFuture' ) ) {
	# Make room in reserves for this before those of a later reserve date
	$priority = _ShiftPriorityByDateAndPriority( $biblionumber, $priority );
    }
    my $waitingdate;

    # If the reserv had the waiting status, we had the value of the resdate
    if ( $found eq 'W' ) {
        $waitingdate = $resdate;
    }

    #eval {
    # updates take place here
    if ( $fee > 0 ) {
        my $nextacctno = &getnextacctno( $borrowernumber );
        my $query      = qq/
        INSERT INTO accountlines
            (borrowernumber,accountno,date,amount,description,accounttype,amountoutstanding)
        VALUES
            (?,?,now(),?,?,'Res',?)
    /;
        my $usth = $dbh->prepare($query);
        $usth->execute( $borrowernumber, $nextacctno, $fee,
            "Reserve Charge - $title", $fee );
    }

    my $query = qq/
        INSERT INTO reserves
            (borrowernumber,biblionumber,reservedate,branchcode,constrainttype,
            priority,reservenotes,itemnumber,found,waitingdate,expirationdate)
        VALUES
             (?,?,?,?,?,
             ?,?,?,?,?,?)
    /;
    my $sth = $dbh->prepare($query);
    $sth->execute(
        $borrowernumber, $biblionumber, $resdate, $branch,
        $const,          $priority,     $notes,   $checkitem,
        $found,          $waitingdate,	$expdate
    );
    my $reserve_id = $sth->{mysql_insertid};

    # Send e-mail to librarian if syspref is active
    if(C4::Context->preference("emailLibrarianWhenHoldIsPlaced")){
        my $borrower = C4::Members::GetMember(borrowernumber => $borrowernumber);
        my $branch_details = C4::Branch::GetBranchDetail($borrower->{branchcode});
        if ( my $letter =  C4::Letters::GetPreparedLetter (
            module => 'reserves',
            letter_code => 'HOLDPLACED',
            branchcode => $branch,
            tables => {
                'branches'  => $branch_details,
                'borrowers' => $borrower,
                'biblio'    => $biblionumber,
                'items'     => $checkitem,
            },
        ) ) {

            my $admin_email_address =$branch_details->{'branchemail'} || C4::Context->preference('KohaAdminEmailAddress');

            C4::Letters::EnqueueLetter(
                {   letter                 => $letter,
                    borrowernumber         => $borrowernumber,
                    message_transport_type => 'email',
                    from_address           => $admin_email_address,
                    to_address           => $admin_email_address,
                }
            );
        }
    }

    return $reserve_id;
}

=head swaggerizeHold

    my $holds = C4::Reserves::swaggerizeHolds( C4::Reserves::GetReservesFromBorrowernumber($borrowernumber) );

Turns Hold-HASHRefs into a type-converted HASH ready for squeezing through an API.
@PARAM1 ARRAYRef of HASHRefs, Hold-HASHRef
        or HASHRef, Hold-HASHRef
@RETURNS ARRAYRef if ARRAYRef was given
         or HASHRef,

@THROWS Koha::Exception::BadParameter, if the given parameter is not an ARRAYRef or HASHRef
=cut

sub swaggerizeHold {
    my ($hold) = @_;
    return undef unless $hold;

    my ($hold) = @_;
    $hold->{biblionumber}   += 0;
    $hold->{borrowernumber} += 0;
    $hold->{itemnumber}     += 0 if $hold->{itemnumber};
    $hold->{reserve_id}     += 0 if $hold->{reserve_id};
    $hold->{priority}       += 0 if defined($hold->{priority});

    if ($hold->{timestamp}) {
        my $dt = DateTime::Format::MySQL->parse_datetime( $hold->{timestamp} );
        $dt->set_time_zone( C4::Context->tz() );
        $hold->{timestamp}      = DateTime::Format::RFC3339->new()->format_datetime($dt);
    }

    return $hold;
}

=head2 GetReserve

    $res = GetReserve( $reserve_id );

    Return the current reserve.

=cut

sub GetReserve {
    my ($reserve_id) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT * FROM reserves WHERE reserve_id = ?";
    my $sth = $dbh->prepare( $query );
    $sth->execute( $reserve_id );
    return $sth->fetchrow_hashref();
}

=head PlaceHold

    C4::Reserves::PlaceHold({biblionumber => 12,
                             itemnumber => 23,
                             borrowernumber => 34,
                             pickupBranch => $pickupBranch,
                             expirationDate => $expDate,
                             suspend_until => $suspendDate,
                            });

@PARAM1 HASHRef, keys:
    {Int} 'borrowernumber', MANDATORY
    {Int} 'itemnumber', OPTIONAL
    {Int} 'biblionumber' MANDATORY if 'itemnumber' is missing
    {String} 'pickupBranch', MANDATORY
    {Date String ISO8601} 'expirationDate', OPTIONAL
    {Date String ISO8601} 'suspend_until', OPTIONAL
@RETURNS HASHRef of the recently added hold.

@THROWS Koha::Exception::BadParameter if proper parameters are lacking.
@THROWS Koha::Exception::DB if there is something wrong when inserting the hold to the database.
@THROWS Koha::Exception::NoPermission if the Borrower doesn't have enough permissions to place a Hold.
@THROWS Koha::Exception::UnknownObject if no Borrower is found.
=cut

sub PlaceHold {
    my $params = shift;

    my $borrowernumber = $params->{borrowernumber};
    my $biblionumber = $params->{biblionumber};
    my $itemnumber = $params->{itemnumber};
    my $pickupBranch = $params->{branchcode};
    my $expirationDate = $params->{expirationdate};
    # AddReserve expects date to be in syspref format
    if ($expirationDate) {
        $expirationDate = C4::Dates->new($expirationDate, 'iso')->output;
    }

    my $borrower = Koha::Borrowers->find($borrowernumber);
    unless ($borrower) {
        Koha::Exception::UnknownObject->throw(error => 'Borrower not found');
    }
    unless ($biblionumber or $itemnumber) {
        Koha::Exception::BadParameter->throw(error => "At least one of biblionumber, itemnumber should be given");
    }
    unless ($pickupBranch) {
        Koha::Exception::BadParameter->throw(error => "Pickup branch is required");
    }

    my $item_biblionumber = C4::Biblio::GetBiblionumberFromItemnumber($itemnumber);
    if ($itemnumber && $biblionumber and $biblionumber != $item_biblionumber) {
        Koha::Exception::BadParameter->throw(error => "Item $itemnumber doesn't belong to biblio $biblionumber");
    }

    $biblionumber ||= $item_biblionumber;
    my $biblio = C4::Biblio::GetBiblio($biblionumber);
    unless ($biblio) {
        Koha::Exception::UnknownObject->throw(error => 'Biblio not found');
    }

    my $can_reserve =
      $itemnumber
      ? CanItemBeReserved( $borrowernumber, $itemnumber )
      : CanBookBeReserved( $borrowernumber, $biblionumber );

    unless ($can_reserve eq 'OK') {
        Koha::Exception::NoPermission->throw(error => "Hold cannot be placed. Reason: $can_reserve");
    }

    my $number_reserves = C4::Reserves::GetReserveCount( $borrowernumber );

    if ( C4::Context->preference('maxreserves') && ($number_reserves >= C4::Context->preference('maxreserves')) ) {
        Koha::Exception::NoPermission->throw(error => "Too many holds: $number_reserves");
    }

    my $priority = C4::Reserves::CalculatePriority($biblionumber);
    $itemnumber ||= undef;

    my $reserve_id = C4::Reserves::AddReserve($pickupBranch, $borrowernumber,
        $biblionumber, 'a', undef, $priority, undef, ($expirationDate ? $expirationDate : undef), undef,
        $biblio->{title}, $itemnumber);

    unless ($reserve_id) {
        Koha::Exception::DB->throw(error => "Database error while placing the hold. See Koha logs for details.");
    }

    my $reserve = C4::Reserves::GetReserve($reserve_id);
    return $reserve;
}

=head2 GetReservesFromBiblionumber

  my $reserves = GetReservesFromBiblionumber({
    biblionumber => $biblionumber,
    [ itemnumber => $itemnumber, ]
    [ all_dates => 1|0 ]
  });

This function gets the list of reservations for one C<$biblionumber>,
returning an arrayref pointing to the reserves for C<$biblionumber>.

By default, only reserves whose start date falls before the current
time are returned.  To return all reserves, including future ones,
the C<all_dates> parameter can be included and set to a true value.

If the C<itemnumber> parameter is supplied, reserves must be targeted
to that item or not targeted to any item at all; otherwise, they
are excluded from the list.

=cut

sub GetReservesFromBiblionumber {
    my ( $params ) = @_;
    my $biblionumber = $params->{biblionumber} or return [];
    my $itemnumber = $params->{itemnumber};
    my $all_dates = $params->{all_dates} // 0;
    my $dbh   = C4::Context->dbh;

    # Find the desired items in the reserves
    my @params;
    my $query = "
        SELECT  reserve_id,
                branchcode,
                timestamp AS rtimestamp,
                priority,
                biblionumber,
                borrowernumber,
                reservedate,
                constrainttype,
                found,
                itemnumber,
                reservenotes,
                expirationdate,
                lowestPriority,
                suspend,
                suspend_until
        FROM     reserves
        WHERE biblionumber = ? ";
    push( @params, $biblionumber );
    unless ( $all_dates ) {
        $query .= " AND reservedate <= CAST(NOW() AS DATE) ";
    }
    if ( $itemnumber ) {
        $query .= " AND ( itemnumber IS NULL OR itemnumber = ? )";
        push( @params, $itemnumber );
    }
    $query .= "ORDER BY priority";
    my $sth = $dbh->prepare($query);
    $sth->execute( @params );
    my $results = $sth->fetchall_arrayref({});
    return $results;
}

=head2 GetReservesFromItemnumber

 ( $reservedate, $borrowernumber, $branchcode, $reserve_id, $waitingdate ) = GetReservesFromItemnumber($itemnumber);

Get the first reserve for a specific item number (based on priority). Returns the abovementioned values for that reserve.

The routine does not look at future reserves (read: item level holds), but DOES include future waits (a confirmed future hold).

=cut

sub GetReservesFromItemnumber {
    my ( $itemnumber ) = @_;
    my $dbh   = C4::Context->dbh;
    my $query = "
    SELECT reservedate,borrowernumber,branchcode,reserve_id,waitingdate
    FROM   reserves
    WHERE  itemnumber=? AND ( reservedate <= CAST(now() AS date) OR
           waitingdate IS NOT NULL )
    ORDER BY priority
    ";
    my $sth_res = $dbh->prepare($query);
    $sth_res->execute($itemnumber);
    my ( $reservedate, $borrowernumber,$branchcode, $reserve_id, $wait ) = $sth_res->fetchrow_array;
    return ( $reservedate, $borrowernumber, $branchcode, $reserve_id, $wait );
}

=head2 GetReservesFromBorrowernumber

    $borrowerreserv = GetReservesFromBorrowernumber($borrowernumber,$tatus);

TODO :: Descritpion

=cut

sub GetReservesFromBorrowernumber {
    my ( $borrowernumber, $status ) = @_;
    my $dbh   = C4::Context->dbh;
    my $sth;
    if ($status) {
        $sth = $dbh->prepare("
            SELECT *
            FROM   reserves
            WHERE  borrowernumber=?
                AND found =?
            ORDER BY reservedate
        ");
        $sth->execute($borrowernumber,$status);
    } else {
        $sth = $dbh->prepare("
            SELECT *
            FROM   reserves
            WHERE  borrowernumber=?
            ORDER BY reservedate
        ");
        $sth->execute($borrowernumber);
    }
    my $data = $sth->fetchall_arrayref({});
    return @$data;
}
#-------------------------------------------------------------------------------------
=head2 CanBookBeReserved

  $canReserve = &CanBookBeReserved($borrowernumber, $biblionumber)
  if ($canReserve eq 'OK') { #We can reserve this Item! }

See CanItemBeReserved() for possible return values.
  This subroutine introduces error codes:
      'noItems', if the Biblio has no Items.

=cut

sub CanBookBeReserved{
    my ($borrowernumber, $biblionumber) = @_;

    my $items = GetItemnumbersForBiblio($biblionumber);
    #get items linked via host records
    my @hostitems = get_hostitemnumbers_of($biblionumber);
    if (@hostitems){
    push (@$items,@hostitems);
    }

    my $canReserve = 'noItems';
    foreach my $item (@$items){
		$canReserve = CanItemBeReserved($borrowernumber, $item);
        return 'OK' if $canReserve eq 'OK';
    }
    return $canReserve;
}

=head2 CanItemBeReserved

  $canReserve = &CanItemBeReserved($borrowernumber, $itemnumber)
  if ($canReserve eq 'OK') { #We can reserve this Item! }

@RETURNS OK,              if the Item can be reserved.
         ageRestricted,   if the Item is age restricted for this borrower.
         damaged,         if the Item is damaged.
         cannotReserveFromOtherBranches, if syspref 'canreservefromotherbranches' is OK.
         tooManyReserves, if the borrower has exceeded his maximum reserve amount.

=cut

sub CanItemBeReserved{
    my ($borrowernumber, $itemnumber) = @_;
    
    my $dbh             = C4::Context->dbh;
    my $ruleitemtype; # itemtype of the matching issuing rule
    my $allowedreserves = 0;
            
    # we retrieve borrowers and items informations #
    # item->{itype} will come for biblioitems if necessery
    my $item = GetItem($itemnumber);
    my $biblioData = C4::Biblio::GetBiblioData( $item->{biblionumber} );
    my $borrower = C4::Members::GetMember('borrowernumber'=>$borrowernumber);

    #KD#1134, Improve authorised values wit allow and deny option
    my $no_reservation = C4::Circulation::IsNoReservationOrCheckout($itemnumber, 'no_reservation');
    return 0 if ($no_reservation);

    ##HACKMAN HERE! certain Items cannot be put on hold!
    if ($item->{homebranch} eq 'JOE_LAKO' || $item->{homebranch} eq 'JOE_LASI' ||
        $item->{itype} eq 'EK') {
        return (0);
    }
    return 0 if ($item->{location} eq 'OHE'); # Oheislukemistot eivät ole varattavissa
    return 0 if ($item->{itype} eq 'DAISY');

    # If an item is damaged and we don't allow holds on damaged items, we can stop right here
    return 'damaged' if ( $item->{damaged} && !C4::Context->preference('AllowHoldsOnDamagedItems') );

    #Check for the age restriction
    my ($ageRestriction, $daysToAgeRestriction) = C4::Circulation::GetAgeRestriction( $biblioData->{agerestriction}, $borrower );
    return 'ageRestricted' if $daysToAgeRestriction && $daysToAgeRestriction > 0;

    my $controlbranch = C4::Context->preference('ReservesControlBranch');
    my $itemtypefield = C4::Context->preference('item-level_itypes') ? "itype" : "itemtype";

    # we retrieve user rights on this itemtype and branchcode
    my $sth = $dbh->prepare("SELECT categorycode, itemtype, branchcode, reservesallowed 
                             FROM issuingrules 
                             WHERE (categorycode in (?,'*') ) 
                             AND (itemtype IN (?,'*')) 
                             AND (branchcode IN (?,'*')) 
                             ORDER BY 
                               categorycode DESC, 
                               itemtype     DESC, 
                               branchcode   DESC;"
                           );
                           
    my $querycount ="SELECT 
                            count(*) as count
                            FROM reserves
                                LEFT JOIN items USING (itemnumber)
                                LEFT JOIN biblioitems ON (reserves.biblionumber=biblioitems.biblionumber)
                                LEFT JOIN borrowers USING (borrowernumber)
                            WHERE borrowernumber = ?
                                ";
    
    
    my $branchcode   = "";
    my $branchfield  = "reserves.branchcode";
    
    if( $controlbranch eq "ItemHomeLibrary" ){
        $branchfield = "items.homebranch";
        $branchcode = $item->{homebranch};
    }elsif( $controlbranch eq "PatronLibrary" ){
        $branchfield = "borrowers.branchcode";
        $branchcode = $borrower->{branchcode};
    }
    
    # we retrieve rights 
    $sth->execute($borrower->{'categorycode'}, $item->{'itype'}, $branchcode);
    if(my $rights = $sth->fetchrow_hashref()){
        $ruleitemtype    = $rights->{itemtype};
        $allowedreserves = $rights->{reservesallowed}; 
    }else{
        $ruleitemtype = '*';
    }
    
    # we retrieve count
    
    $querycount .= "AND $branchfield = ?";
    
    $querycount .= " AND $itemtypefield = ?" if ($ruleitemtype ne "*");
    my $sthcount = $dbh->prepare($querycount);
    
    if($ruleitemtype eq "*"){
        $sthcount->execute($borrowernumber, $branchcode);
    }else{
        $sthcount->execute($borrowernumber, $branchcode, $ruleitemtype);
    }
    
    my $reservecount = "0";
    if(my $rowcount = $sthcount->fetchrow_hashref()){
        $reservecount = $rowcount->{count};
    }
    
    # we check if it's ok or not
    if( $reservecount >= $allowedreserves ){
        return 'tooManyReserves';
    }

    # If reservecount is ok, we check item branch if IndependentBranches is ON
    # and canreservefromotherbranches is OFF
    if ( C4::Context->preference('IndependentBranches')
        and !C4::Context->preference('canreservefromotherbranches') )
    {
        my $itembranch = $item->{homebranch};
        if ($itembranch ne $borrower->{branchcode}) {
            return 'cannotReserveFromOtherBranches';
        }
    }

    return 'OK';
}

=head2 CanReserveBeCanceledFromOpac

    $number = CanReserveBeCanceledFromOpac($reserve_id, $borrowernumber);

    returns 1 if reserve can be cancelled by user from OPAC.
    First check if reserve belongs to user, next checks if reserve is not in
    transfer or waiting status

=cut

sub CanReserveBeCanceledFromOpac {
    my ($reserve_id, $borrowernumber) = @_;

    return unless $reserve_id and $borrowernumber;
    my $reserve = GetReserve($reserve_id);

    return 0 unless $reserve->{borrowernumber} == $borrowernumber;
    return 0 if ( $reserve->{found} eq 'W' ) or ( $reserve->{found} eq 'T' );

    return 1;

}

#--------------------------------------------------------------------------------
=head2 GetReserveCount

  $number = &GetReserveCount($borrowernumber);

this function returns the number of reservation for a borrower given on input arg.

=cut

sub GetReserveCount {
    my ($borrowernumber) = @_;

    my $dbh = C4::Context->dbh;

    my $query = "
        SELECT COUNT(*) AS counter
        FROM reserves
        WHERE borrowernumber = ?
    ";
    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    my $row = $sth->fetchrow_hashref;
    return $row->{counter};
}

=head2 GetOtherReserves

  ($messages,$nextreservinfo)=$GetOtherReserves(itemnumber);

Check queued list of this document and check if this document must be  transfered

=cut

sub GetOtherReserves {
    my ($itemnumber) = @_;
    my $messages;
    my $nextreservinfo;
    my ( undef, $checkreserves, undef ) = CheckReserves($itemnumber);
    if ($checkreserves) {
        my $iteminfo = GetItem($itemnumber);
        if ( $iteminfo->{'holdingbranch'} ne $checkreserves->{'branchcode'} ) {
            $messages->{'transfert'} = $checkreserves->{'branchcode'};
            #minus priorities of others reservs
            ModReserveMinusPriority(
                $itemnumber,
                $checkreserves->{'reserve_id'},
            );

            #launch the subroutine dotransfer
            C4::Items::ModItemTransfer(
                $itemnumber,
                $iteminfo->{'holdingbranch'},
                $checkreserves->{'branchcode'}
              ),
              ;
        }

     #step 2b : case of a reservation on the same branch, set the waiting status
        else {
            $messages->{'waiting'} = 1;
            ModReserveMinusPriority(
                $itemnumber,
                $checkreserves->{'reserve_id'},
            );
            ModReserveStatus($itemnumber,'W');
        }

        $nextreservinfo = $checkreserves->{'borrowernumber'};
    }

    return ( $messages, $nextreservinfo );
}

=head2 GetReserveFee

  $fee = GetReserveFee($borrowernumber,$biblionumber,$constraint,$biblionumber);

Calculate the fee for a reserve

=cut

sub GetReserveFee {
    my ($borrowernumber, $biblionumber, $constraint, $bibitems ) = @_;

    #check for issues;
    my $dbh   = C4::Context->dbh;
    my $const = lc substr( $constraint, 0, 1 );
    my $query = qq/
      SELECT * FROM borrowers
    LEFT JOIN categories ON borrowers.categorycode = categories.categorycode
    WHERE borrowernumber = ?
    /;
    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    my $data = $sth->fetchrow_hashref;
    my $fee      = $data->{'reservefee'};
    my $cntitems = @- > $bibitems;
    #Kyyti#993, remove predefined reserve payment from certain location;
    $fee = 0 if C4::Context->preference("ReserveFeeOnNotify");

    if ( $fee > 0 ) {

        # check for items on issue
        # first find biblioitem records
        my @biblioitems;
        my $sth1 = $dbh->prepare(
            "SELECT * FROM biblio LEFT JOIN biblioitems on biblio.biblionumber = biblioitems.biblionumber
                   WHERE (biblio.biblionumber = ?)"
        );
        $sth1->execute($biblionumber);
        while ( my $data1 = $sth1->fetchrow_hashref ) {
            if ( $const eq "a" ) {
                push @biblioitems, $data1;
            }
            else {
                my $found = 0;
                my $x     = 0;
                while ( $x < $cntitems ) {
                    if ( @$bibitems->{'biblioitemnumber'} ==
                        $data->{'biblioitemnumber'} )
                    {
                        $found = 1;
                    }
                    $x++;
                }
                if ( $const eq 'o' ) {
                    if ( $found == 1 ) {
                        push @biblioitems, $data1;
                    }
                }
                else {
                    if ( $found == 0 ) {
                        push @biblioitems, $data1;
                    }
                }
            }
        }
        my $cntitemsfound = @biblioitems;
        my $issues        = 0;
        my $x             = 0;
        my $allissued     = 1;
        while ( $x < $cntitemsfound ) {
            my $bitdata = $biblioitems[$x];
            my $sth2    = $dbh->prepare(
                "SELECT * FROM items
                     WHERE biblioitemnumber = ?"
            );
            $sth2->execute( $bitdata->{'biblioitemnumber'} );
            while ( my $itdata = $sth2->fetchrow_hashref ) {
                my $sth3 = $dbh->prepare(
                    "SELECT * FROM issues
                       WHERE itemnumber = ?"
                );
                $sth3->execute( $itdata->{'itemnumber'} );
                if ( my $isdata = $sth3->fetchrow_hashref ) {
                }
                else {
                    $allissued = 0;
                }
            }
            $x++;
        }
        if ( $allissued == 0 ) {
            my $rsth =
              $dbh->prepare("SELECT * FROM reserves WHERE biblionumber = ?");
            $rsth->execute($biblionumber);
            if ( my $rdata = $rsth->fetchrow_hashref ) {
            }
            else {
                #$fee = 0; #HACKMAN HERE
            }
        }

    }
    return $fee;
}

=head2 GetReservesToBranch

  @transreserv = GetReservesToBranch( $frombranch );

Get reserve list for a given branch

=cut

sub GetReservesToBranch {
    my ( $frombranch ) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        "SELECT reserve_id,borrowernumber,reservedate,itemnumber,timestamp
         FROM reserves 
         WHERE priority='0' 
           AND branchcode=?"
    );
    $sth->execute( $frombranch );
    my @transreserv;
    my $i = 0;
    while ( my $data = $sth->fetchrow_hashref ) {
        $transreserv[$i] = $data;
        $i++;
    }
    return (@transreserv);
}

=head2 GetReservesForBranch

  @transreserv = GetReservesForBranch($frombranch);

=cut

sub GetReservesForBranch {
    my ($frombranch) = @_;
    my $dbh = C4::Context->dbh;

    my $query = "
        SELECT reserve_id,borrowernumber,reservedate,itemnumber,waitingdate,branchcode
        FROM   reserves 
        WHERE   priority='0'
        AND found='W'
    ";
    $query .= " AND branchcode=? " if ( $frombranch );
    $query .= "ORDER BY waitingdate" ;

    my $sth = $dbh->prepare($query);
    if ($frombranch){
     $sth->execute($frombranch);
    } else {
        $sth->execute();
    }

    my @transreserv;
    my $i = 0;
    while ( my $data = $sth->fetchrow_hashref ) {
        $transreserv[$i] = $data;
        $i++;
    }
    return (@transreserv);
}

=head GetExpiredReserves

    my $expiredReserves = C4::Reserves::GetExpiredReserves(
            {branchcode => 'CPL',
            from => DateTime->new(...), #DateTime or undef
                #defaults to 'PickupExpiredHoldsOverReportDuration' days ago.
                #respects Koha::Calendar for the given branch, skipping closed days.
            to   => DateTime->now(), #DateTime or undef
                #defaults to now()
        });

@RETURNS ARRAYRef of expired reserves from the given duration.
=cut

sub GetExpiredReserves {
    my ($params) = @_;

    my $pickupExpiredHoldsOverReportDuration = C4::Context->preference('PickupExpiredHoldsOverReportDuration');
    return [] unless $pickupExpiredHoldsOverReportDuration;

    my $branchcode = $params->{branchcode};
    if ($params->{from}) {
        unless (blessed($params->{from}) && $params->{from}->isa('DateTime')) {
            Koha::Exception::BadParameter->throw(error => "GetExpiredReserves():> Parameter 'from' is not a DateTime-object or undef!");
        }
    }
    if ($params->{to}) {
        unless (blessed($params->{from}) && $params->{from}->isa('DateTime')) {
            Koha::Exception::BadParameter->throw(error => "GetExpiredReserves():> Parameter 'from' is not a DateTime-object or undef!");
        }
    }

    #Calculate the days for which we get the expired reserves.
    my $fromDate   = $params->{from};
    my $toDate     = $params->{to}   || DateTime->now(time_zone => C4::Context->tz());
    unless ($fromDate) {
        $fromDate = DateTime->now( time_zone => C4::Context->tz() );

        #Look for previous open days
        if ($branchcode) {
            my $calendar = Koha::Calendar->new( branchcode => $branchcode );
            foreach my $i (1..$pickupExpiredHoldsOverReportDuration) {
                $fromDate = $calendar->prev_open_day($fromDate);
            }
        }
        #If no branch has been specified we cannot use a calendar, so simply just go back in time.
        else {
            $fromDate = DateTime->now(time_zone => C4::Context->tz())->subtract(days => $pickupExpiredHoldsOverReportDuration);
        }
    }

    my $dbh = C4::Context->dbh;

    my @params = ($fromDate->ymd(), $toDate->ymd());
    my $query = "
        SELECT *
        FROM   old_reserves
        WHERE   priority='0'
        AND pickupexpired BETWEEN ? AND ?
    ";
    if ( $branchcode ) {
        push @params, $branchcode;
        $query .= " AND branchcode=? ";
    }
    $query .= "ORDER BY waitingdate" ;

    my $sth = $dbh->prepare($query);
    $sth->execute(@params);

    my $data = $sth->fetchall_arrayref({});
    return ($data) ? $data : [];
}

=head2 GetReserveStatus

  $reservestatus = GetReserveStatus($itemnumber, $biblionumber);

Take an itemnumber or a biblionumber and return the status of the reserve places on it.
If several reserves exist, the reserve with the lower priority is given.

=cut

## FIXME: I don't think this does what it thinks it does.
## It only ever checks the first reserve result, even though
## multiple reserves for that bib can have the itemnumber set
## the sub is only used once in the codebase.
sub GetReserveStatus {
    my ($itemnumber, $biblionumber) = @_;

    my $dbh = C4::Context->dbh;

    my ($sth, $found, $priority);
    if ( $itemnumber ) {
        $sth = $dbh->prepare("SELECT found, priority FROM reserves WHERE itemnumber = ? order by priority LIMIT 1");
        $sth->execute($itemnumber);
        ($found, $priority) = $sth->fetchrow_array;
    }

    if ( $biblionumber and not defined $found and not defined $priority ) {
        $sth = $dbh->prepare("SELECT found, priority FROM reserves WHERE biblionumber = ? order by priority LIMIT 1");
        $sth->execute($biblionumber);
        ($found, $priority) = $sth->fetchrow_array;
    }

    if(defined $found) {
        return 'Waiting'  if ($found eq 'W' || $found eq 'T') and $priority == 0;
        return 'Finished' if $found eq 'F';
    }

    return 'Reserved' if $priority > 0;

    return ''; # empty string here will remove need for checking undef, or less log lines
}

=head2 CheckReserves

  ($status, $reserve, $all_reserves) = &CheckReserves($itemnumber);
  ($status, $reserve, $all_reserves) = &CheckReserves(undef, $barcode);
  ($status, $reserve, $all_reserves) = &CheckReserves($itemnumber,undef,$lookahead);

Find a book in the reserves.

C<$itemnumber> is the book's item number.
C<$lookahead> is the number of days to look in advance for future reserves.

As I understand it, C<&CheckReserves> looks for the given item in the
reserves. If it is found, that's a match, and C<$status> is set to
C<Waiting>.

Otherwise, it finds the most important item in the reserves with the
same biblio number as this book (I'm not clear on this) and returns it
with C<$status> set to C<Reserved>.

C<&CheckReserves> returns a two-element list:

C<$status> is either C<Waiting>, C<Reserved> (see above), or 0.

C<$reserve> is the reserve item that matched. It is a
reference-to-hash whose keys are mostly the fields of the reserves
table in the Koha database.

=cut

sub CheckReserves {
    my ( $item, $barcode, $lookahead_days) = @_;
    my $dbh = C4::Context->dbh;
    my $sth;
    my $select;
    if (C4::Context->preference('item-level_itypes')){
	$select = "
           SELECT items.biblionumber,
           items.biblioitemnumber,
           itemtypes.notforloan,
           items.notforloan AS itemnotforloan,
           items.itemnumber,
           items.homebranch,
           items.ccode,
           items.itype,
           items.permanent_location,
           items.damaged
           FROM   items
           LEFT JOIN biblioitems ON items.biblioitemnumber = biblioitems.biblioitemnumber
           LEFT JOIN itemtypes   ON items.itype   = itemtypes.itemtype
        ";
    }
    else {
	$select = "
           SELECT items.biblionumber,
           items.biblioitemnumber,
           itemtypes.notforloan,
           items.notforloan AS itemnotforloan,
           items.itemnumber,
           items.homebranch,
           items.ccode,
           items.itype,
           items.permanent_location,
           items.damaged
           FROM   items
           LEFT JOIN biblioitems ON items.biblioitemnumber = biblioitems.biblioitemnumber
           LEFT JOIN itemtypes   ON biblioitems.itemtype   = itemtypes.itemtype
        ";
    }
   
    if ($item) {
        $sth = $dbh->prepare("$select WHERE itemnumber = ?");
        $sth->execute($item);
    }
    else {
        $sth = $dbh->prepare("$select WHERE barcode = ?");
        $sth->execute($barcode);
    }
    # note: we get the itemnumber because we might have started w/ just the barcode.  Now we know for sure we have it.
    my ( $biblio, $bibitem, $notforloan_per_itemtype, $notforloan_per_item, $itemnumber, $homebranch, $ccode, $itype, $permanent_location, $damaged ) = $sth->fetchrow_array;

    return if ( $damaged && !C4::Context->preference('AllowHoldsOnDamagedItems') );

    return unless $itemnumber; # bail if we got nothing.

    # if item is not for loan it cannot be reserved either.....
    #    execpt where items.notforloan < 0 :  This indicates the item is holdable. 
    return if  ( $notforloan_per_item > 0 ) or $notforloan_per_itemtype;

    #KD#1134, Improve authorised values wit allow and deny option
    my $no_reservation = C4::Circulation::IsNoReservationOrCheckout($itemnumber, 'no_reservation');
    return if ($no_reservation);

    #HACKMAN HERE: Don't catch certain Items for reservation/holding!
    return if ($homebranch eq 'JOE_LAKO' || $homebranch eq 'JOE_LASI' ||
               $itype eq 'EK');

    # Find this item in the reserves
    my @reserves = _Findgroupreserve( $bibitem, $biblio, $itemnumber, $lookahead_days);

    # $priority and $highest are used to find the most important item
    # in the list returned by &_Findgroupreserve. (The lower $priority,
    # the more important the item.)
    # $highest is the most important item we've seen so far.
    my $highest;
    if (scalar @reserves) {
        my $priority = 10000000;
        foreach my $res (@reserves) {
            if ( $res->{'itemnumber'} == $itemnumber && $res->{'priority'} == 0) {
                return ( "Waiting", $res, \@reserves ); # Found it
            } else {
                # See if this item is more important than what we've got so far
                if ( $res->{'priority'} && $res->{'priority'} < $priority ) {
                    my $borrowerinfo=C4::Members::GetMember(borrowernumber => $res->{'borrowernumber'});
                    my $iteminfo=C4::Items::GetItem($itemnumber);
                    my $branch = GetReservesControlBranch( $iteminfo, $borrowerinfo );
                    my $branchitemrule = C4::Circulation::GetBranchItemRule($branch,$iteminfo->{'itype'});
                    next if ($branchitemrule->{'holdallowed'} == 0);
                    next if (($branchitemrule->{'holdallowed'} == 1) && ($branch ne $borrowerinfo->{'branchcode'}));
                    $priority = $res->{'priority'};
                    $highest  = $res;
                }
            }
        }
    }

    # If we get this far, then no exact match was found.
    # We return the most important (i.e. next) reservation.
    if ($highest) {
        $highest->{'itemnumber'} = $item;
        return ( "Reserved", $highest, \@reserves );
    }

    return ( '' );
}

=head2 CancelExpiredReserves

  CancelExpiredReserves(); #Brief
  my $verboseLog = CancelExpiredReserves(2); #Verbose level 2

Cancels all reserves with an expiration date from before today.

@PARAM1 Integer, to define the verbosity level. 0 or undef to be brief.
                 Supported values, 0,1,2,3.
RETURNS String, the verbose output. Returns the output instead of printing it to
                make it possible to run this module from a CGI-script.

=cut

sub CancelExpiredReserves {
    my $verbose = shift;
    my @sb; #Efficiently collect verbose output here.
    my %usedCalendars; #Collect all used calendars here so they can be logged if verbose enough

    # Cancel reserves that have passed their expiration date.
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( "
        SELECT * FROM reserves WHERE DATE(expirationdate) < DATE( CURDATE() ) 
        AND expirationdate IS NOT NULL
        AND found IS NULL
    " );
    $sth->execute();

    push @sb, "##Checking reserve expirationdates\n".
          "reserve_id|borrowernumber|expirationdate|\n" if $verbose;

    while ( my $res = $sth->fetchrow_hashref() ) {
        CancelReserve({ reserve_id => $res->{'reserve_id'} });
        push @sb, printReserve($res,'tab',['reserve_id','borrowernumber','expirationdate'])." expired.\n" if $verbose;
    }

    # Cancel reserves that have been waiting too long
    if ( C4::Context->preference("ExpireReservesMaxPickUpDelay") ) {
        my $max_pickup_delay = C4::Context->preference("ReservesMaxPickUpDelay");
        my $charge = C4::Context->preference("ExpireReservesMaxPickUpDelayCharge");

        my $query = "SELECT * FROM reserves WHERE TO_DAYS( NOW() ) - TO_DAYS( waitingdate ) > ? AND found = 'W' AND priority = 0";
        $sth = $dbh->prepare( $query );
        $sth->execute( $max_pickup_delay );

        my $today = DateTime->now( time_zone => C4::Context->tz() );

        push @sb, "##Removing holds waiting too long\n##using today=$today, ReservesMaxPickUpDelay=$max_pickup_delay, ExpireReservesMaxPickUpDelayCharge=$charge\n".
              "reserve_id|borrowernumber|branchcode|waitingdate|lastpickupdate|resolution\n" if $verbose;

        while (my $res = $sth->fetchrow_hashref ) {
            my $expiration = _reserve_last_pickup_date( $res );
            if ( $today > $expiration ) {
                if ( $charge ) {
                    manualinvoice($res->{'borrowernumber'}, $res->{'itemnumber'}, '', 'HE', $charge);
                }
                CancelReserve({ reserve_id => $res->{'reserve_id'},
                                pickupexpired => $expiration,
                            });
                push @sb, printReserve($res,'tab',['reserve_id','borrowernumber','branchcode','waitingdate']).sprintf("% 14s",substr($expiration,0,10))."| past lastpickupdate.\n" if $verbose;
            }
            elsif($verbose > 1) {
                push @sb, printReserve($res,'tab',['reserve_id','borrowernumber','branchcode','waitingdate']).sprintf("% 14s",substr($expiration,0,10))."| still waiting.\n" if $verbose > 1;
            }
            $usedCalendars{  $res->{branchcode}  } = Koha::Calendar->new( branchcode => $res->{branchcode} ) if (  $verbose > 2 && not(exists($usedCalendars{$res->{branchcode}}))  );
        }

        #Log the used calendars.
        if ($verbose > 2) {
            push @sb, "##Dumping used Calendars\n";
            foreach my $branchcode (sort keys %usedCalendars) {
                my $calendar = $usedCalendars{$branchcode};
                push @sb, "<<  $branchcode >>\n";
                push @sb, $calendar->printMe()."\n";
            }
        }

    }
    return join('',@sb) if $verbose;
}

=head2 AutoUnsuspendReserves

  AutoUnsuspendReserves();

Unsuspends all suspended reserves with a suspend_until date from before today.

=cut

sub AutoUnsuspendReserves {

    my $dbh = C4::Context->dbh;

    my $query = "UPDATE reserves SET suspend = 0, suspend_until = NULL WHERE DATE( suspend_until ) < DATE( CURDATE() )";
    my $sth = $dbh->prepare( $query );
    $sth->execute();

}

=head2 CancelReserve

  CancelReserve({ reserve_id => $reserve_id,
                  [ biblionumber => $biblionumber,
                    borrowernumber => $borrrowernumber,
                    itemnumber => $itemnumber ],
                  pickupexpired => DateTime->new(year => 2015, ...), #If the reserve was waiting for pickup, set the date the pickup wait period expired.
                });

Cancels a reserve.

=cut

sub CancelReserve {
    my ( $params ) = @_;

    my $reserve_id = $params->{'reserve_id'};
    my $pickupexpired = $params->{pickupexpired};
    if ($pickupexpired) {
        unless (blessed($pickupexpired) && $pickupexpired->isa('DateTime')) {
            Koha::Exception::BadParameter->throw(error => "CancelReserve():> Parameter 'pickupexpired' is not a DateTime-object or undef!");
        }
    }

    $reserve_id = GetReserveId( $params ) unless ( $reserve_id );

    return unless ( $reserve_id );

    my $dbh = C4::Context->dbh;

    my $reserve = GetReserve( $reserve_id );

    my @params;
    my $query = "
        UPDATE reserves
        SET    cancellationdate = DATE(NOW()),
               found            = Null,
    ";
    if ($pickupexpired) {
        push @params, $pickupexpired->ymd();
        $query .= "
               pickupexpired    = ?,
        ";
    }
    push @params, $reserve_id;
    $query .= "
               priority         = 0
        WHERE  reserve_id = ?
    ";
    my $sth = $dbh->prepare($query);
    $sth->execute( @params );

    $query = "
        INSERT INTO old_reserves
        SELECT * FROM reserves
        WHERE  reserve_id = ?
    ";
    $sth = $dbh->prepare($query);
    $sth->execute( $reserve_id );

    $query = "
        DELETE FROM reserves
        WHERE  reserve_id = ?
    ";
    $sth = $dbh->prepare($query);
    $sth->execute( $reserve_id );

    # now fix the priority on the others....
    _FixPriority({ biblionumber => $reserve->{biblionumber} });
}

=head2 ModReserve

  ModReserve({ rank => $rank,
               reserve_id => $reserve_id,
               branchcode => $branchcode
               [, itemnumber => $itemnumber ]
               [, biblionumber => $biblionumber, $borrowernumber => $borrowernumber ]
              });

Change a hold request's priority or cancel it.

C<$rank> specifies the effect of the change.  If C<$rank>
is 'W' or 'n', nothing happens.  This corresponds to leaving a
request alone when changing its priority in the holds queue
for a bib.

If C<$rank> is 'del', the hold request is cancelled.

If C<$rank> is an integer greater than zero, the priority of
the request is set to that value.  Since priority != 0 means
that the item is not waiting on the hold shelf, setting the 
priority to a non-zero value also sets the request's found
status and waiting date to NULL. 

The optional C<$itemnumber> parameter is used only when
C<$rank> is a non-zero integer; if supplied, the itemnumber 
of the hold request is set accordingly; if omitted, the itemnumber
is cleared.

B<FIXME:> Note that the forgoing can have the effect of causing
item-level hold requests to turn into title-level requests.  This
will be fixed once reserves has separate columns for requested
itemnumber and supplying itemnumber.

=cut

sub ModReserve {
    my ( $params ) = @_;

    my $rank = $params->{'rank'};
    my $reserve_id = $params->{'reserve_id'};
    my $branchcode = $params->{'branchcode'};
    my $itemnumber = $params->{'itemnumber'};
    my $suspend_until = $params->{'suspend_until'};
    my $borrowernumber = $params->{'borrowernumber'};
    my $biblionumber = $params->{'biblionumber'};

    return if $rank eq "W";
    return if $rank eq "n";

    return unless ( $reserve_id || ( $borrowernumber && ( $biblionumber || $itemnumber ) ) );
    $reserve_id = GetReserveId({ biblionumber => $biblionumber, borrowernumber => $borrowernumber, itemnumber => $itemnumber }) unless ( $reserve_id );

    my $dbh = C4::Context->dbh;
    if ( $rank eq "del" ) {
        CancelReserve({ reserve_id => $reserve_id });
    }
    elsif ($rank =~ /^\d+/ and $rank > 0) {
        my $query = "
            UPDATE reserves SET priority = ? ,branchcode = ?, itemnumber = ?, found = NULL, waitingdate = NULL
            WHERE reserve_id = ?
        ";
        my $sth = $dbh->prepare($query);
        $sth->execute( $rank, $branchcode, $itemnumber, $reserve_id );

        if ( defined( $suspend_until ) ) {
            if ( $suspend_until ) {
                $suspend_until = C4::Dates->new( $suspend_until )->output("iso");
                $dbh->do("UPDATE reserves SET suspend = 1, suspend_until = ? WHERE reserve_id = ?", undef, ( $suspend_until, $reserve_id ) );
            } else {
                $dbh->do("UPDATE reserves SET suspend_until = NULL WHERE reserve_id = ?", undef, ( $reserve_id ) );
            }
        }

        _FixPriority({ reserve_id => $reserve_id, rank =>$rank });
    }
}

=head2 ModReserveFill

  &ModReserveFill($reserve);

Fill a reserve. If I understand this correctly, this means that the
reserved book has been found and given to the patron who reserved it.

C<$reserve> specifies the reserve to fill. It is a reference-to-hash
whose keys are fields from the reserves table in the Koha database.

=cut

sub ModReserveFill {
    my ($res) = @_;
    my $dbh = C4::Context->dbh;
    # fill in a reserve record....
    my $reserve_id = $res->{'reserve_id'};
    my $biblionumber = $res->{'biblionumber'};
    my $borrowernumber    = $res->{'borrowernumber'};
    my $resdate = $res->{'reservedate'};

    $reserve_id = GetReserveId({biblionumber   => $biblionumber,
			        borrowernumber => $borrowernumber,
			        reservedate    => $resdate}) if (!$reserve_id);
    return if (!$reserve_id);

    # get the priority on this record....
    my $priority;
    my $query = "SELECT priority
                 FROM   reserves
                 WHERE  reserve_id = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute( $reserve_id );
    ($priority) = $sth->fetchrow_array;

    # update the database...
    $query = "UPDATE reserves
                  SET    found            = 'F',
                         priority         = 0
                 WHERE  reserve_id        = ?";
    $sth = $dbh->prepare($query);
    $sth->execute( $reserve_id );

    # move to old_reserves
    $query = "INSERT INTO old_reserves
                 SELECT * FROM reserves
                 WHERE  reserve_id  = ?";
    $sth = $dbh->prepare($query);
    $sth->execute( $reserve_id );
    $query = "DELETE FROM reserves
                 WHERE  reserve_id = ?";
    $sth = $dbh->prepare($query);
    $sth->execute( $reserve_id );

    # now fix the priority on the others (if the priority wasn't
    # already sorted!)....
    unless ( $priority == 0 ) {
        _FixPriority({ reserve_id => $reserve_id });
    }
}

=head2 ModReserveStatus

  &ModReserveStatus($itemnumber, $newstatus);

Update the reserve status for the active (priority=0) reserve.

$itemnumber is the itemnumber the reserve is on

$newstatus is the new status.

=cut

sub ModReserveStatus {

    #first : check if we have a reservation for this item .
    my ($itemnumber, $newstatus) = @_;
    my $dbh = C4::Context->dbh;

    my $query = "UPDATE reserves SET found = ?, waitingdate = NOW() WHERE itemnumber = ? AND found IS NULL AND priority = 0";
    my $sth_set = $dbh->prepare($query);
    $sth_set->execute( $newstatus, $itemnumber );

    if ( C4::Context->preference("ReturnToShelvingCart") && $newstatus ) {
      CartToShelf( $itemnumber );
    }
}

=head2 ModReserveAffect

  &ModReserveAffect($itemnumber,$borrowernumber,$diffBranchSend);

This function affect an item and a status for a given reserve
The itemnumber parameter is used to find the biblionumber.
with the biblionumber & the borrowernumber, we can affect the itemnumber
to the correct reserve.

if $transferToDo is not set, then the status is set to "Waiting" as well.
otherwise, a transfer is on the way, and the end of the transfer will 
take care of the waiting status

=cut

sub ModReserveAffect {
    my ( $itemnumber, $borrowernumber,$transferToDo ) = @_;
    my $dbh = C4::Context->dbh;

    # we want to attach $itemnumber to $borrowernumber, find the biblionumber
    # attached to $itemnumber
    my $sth = $dbh->prepare("SELECT biblionumber FROM items WHERE itemnumber=?");
    $sth->execute($itemnumber);
    my ($biblionumber) = $sth->fetchrow;

    my $reserve_id = GetReserveNextEligible({
	    borrowernumber => $borrowernumber,
	    biblionumber   => $biblionumber,
	    itemnumber     => $itemnumber
					    });

    return unless defined $reserve_id;
    my $request = GetReserveInfo($reserve_id);

    # If we affect a reserve that has to be transfered, don't set to Waiting
    my $query;
    if ($transferToDo) {
    $query = "
        UPDATE reserves
        SET    priority = 0,
               itemnumber = ?,
               found = 'T'
        WHERE reserve_id = ?
    ";
    }
    else {
    # affect the reserve to Waiting as well.
        $query = "
            UPDATE reserves
            SET     priority = 0,
                    found = 'W',
                    waitingdate = NOW(),
                    itemnumber = ?
            WHERE reserve_id = ?
        ";
    }
    $sth = $dbh->prepare($query);
    $sth->execute( $itemnumber, $reserve_id );
    _koha_notify_reserve( $itemnumber, $borrowernumber, $biblionumber, $reserve_id ) if ( !$transferToDo );

    if ( $request && $request->{priority} != 0 ) {
        _FixPriority({ reserve_id => $reserve_id });
    }

    if ( C4::Context->preference("ReturnToShelvingCart") ) {
      CartToShelf( $itemnumber );
    }

    return;
}

=head2 ModReserveCancelAll

  ($messages,$nextreservinfo) = &ModReserveCancelAll($itemnumber,$borrowernumber);

function to cancel reserv,check other reserves, and transfer document if it's necessary

=cut

sub ModReserveCancelAll {
    my $messages;
    my $nextreservinfo;
    my ( $itemnumber, $borrowernumber ) = @_;

    #step 1 : cancel the reservation
    my $CancelReserve = CancelReserve({ itemnumber => $itemnumber, borrowernumber => $borrowernumber });

    #step 2 launch the subroutine of the others reserves
    ( $messages, $nextreservinfo ) = GetOtherReserves($itemnumber);

    return ( $messages, $nextreservinfo );
}

=head2 ModReserveMinusPriority

  &ModReserveMinusPriority($itemnumber,$borrowernumber,$biblionumber)

Reduce the values of queued list

=cut

sub ModReserveMinusPriority {
    my ( $itemnumber, $reserve_id ) = @_;

    #first step update the value of the first person on reserv
    my $dbh   = C4::Context->dbh;
    my $query = "
        UPDATE reserves
        SET    priority = 0 , itemnumber = ? 
        WHERE  reserve_id = ?
    ";
    my $sth_upd = $dbh->prepare($query);
    $sth_upd->execute( $itemnumber, $reserve_id );
    # second step update all others reserves
    _FixPriority({ reserve_id => $reserve_id, rank => '0' });
}

=head2 GetReserveInfo

  &GetReserveInfo($reserve_id);

Get item and borrower details for a current hold.
Current implementation this query should have a single result.

=cut

sub GetReserveInfo {
    my ( $reserve_id ) = @_;
    my $dbh = C4::Context->dbh;
    my $strsth="SELECT
                   reserve_id,
                   reservedate,
                   reservenotes,
                   reserves.borrowernumber,
                   reserves.biblionumber,
                   reserves.branchcode,
                   reserves.waitingdate,
                   notificationdate,
                   reminderdate,
                   priority,
                   found,
                   firstname,
                   surname,
                   phone,
                   email,
                   address,
                   address2,
                   cardnumber,
                   city,
                   zipcode,
                   biblio.title,
                   biblio.author,
                   items.holdingbranch,
                   items.itemcallnumber,
                   items.itemnumber,
                   items.location,
                   barcode,
                   notes
                FROM reserves
                LEFT JOIN items USING(itemnumber)
                LEFT JOIN borrowers USING(borrowernumber)
                LEFT JOIN biblio ON  (reserves.biblionumber=biblio.biblionumber)
                WHERE reserves.reserve_id = ?";
    my $sth = $dbh->prepare($strsth);
    $sth->execute($reserve_id);

    my $data = $sth->fetchrow_hashref;
    return $data;
}

=head2 IsAvailableForItemLevelRequest

  my $is_available = IsAvailableForItemLevelRequest($itemnumber);

Checks whether a given item record is available for an
item-level hold request.  An item is available if

* it is not lost AND 
* it is not damaged AND 
* it is not withdrawn AND 
* does not have a not for loan value > 0

Whether or not the item is currently on loan is 
also checked - if the AllowOnShelfHolds system preference
is ON, an item can be requested even if it is currently
on loan to somebody else.  If the system preference
is OFF, an item that is currently checked out cannot
be the target of an item-level hold request.

Note that IsAvailableForItemLevelRequest() does not
check if the staff operator is authorized to place
a request on the item - in particular,
this routine does not check IndependentBranches
and canreservefromotherbranches.

=cut

sub IsAvailableForItemLevelRequest {
    my $itemnumber = shift;
   
    my $item = GetItem($itemnumber);

    # must check the notforloan setting of the itemtype
    # FIXME - a lot of places in the code do this
    #         or something similar - need to be
    #         consolidated
    my $dbh = C4::Context->dbh;
    my $notforloan_query;
    if (C4::Context->preference('item-level_itypes')) {
        $notforloan_query = "SELECT itemtypes.notforloan
                             FROM items
                             JOIN itemtypes ON (itemtypes.itemtype = items.itype)
                             WHERE itemnumber = ?";
    } else {
        $notforloan_query = "SELECT itemtypes.notforloan
                             FROM items
                             JOIN biblioitems USING (biblioitemnumber)
                             JOIN itemtypes USING (itemtype)
                             WHERE itemnumber = ?";
    }
    my $sth = $dbh->prepare($notforloan_query);
    $sth->execute($itemnumber);
    my $notforloan_per_itemtype = 0;
    if (my ($notforloan) = $sth->fetchrow_array) {
        $notforloan_per_itemtype = 1 if $notforloan;
    }

    my $available_per_item = 1;
    $available_per_item = 0 if $item->{itemlost} or
                               ( $item->{notforloan} > 0 ) or
                               ($item->{damaged} and not C4::Context->preference('AllowHoldsOnDamagedItems')) or
                               $item->{withdrawn} or
                               $notforloan_per_itemtype;


    if (C4::Context->preference('AllowOnShelfHolds')) {
        return $available_per_item;
    } else {
        return ($available_per_item and ($item->{onloan} or GetReserveStatus($itemnumber) eq "Waiting"));
    }
}

=head2 AlterPriority

  AlterPriority( $where, $reserve_id );

This function changes a reserve's priority up, down, to the top, or to the bottom.
Input: $where is 'up', 'down', 'top' or 'bottom'. Biblionumber, Date reserve was placed

=cut

sub AlterPriority {
    my ( $where, $reserve_id ) = @_;

    my $dbh = C4::Context->dbh;

    my $reserve = GetReserve( $reserve_id );

    if ( $reserve->{cancellationdate} ) {
        warn "I cannot alter the priority for reserve_id $reserve_id, the reserve has been cancelled (".$reserve->{cancellationdate}.')';
        return;
    }

    if ( $where eq 'up' || $where eq 'down' ) {

      my $priority = $reserve->{'priority'};
      $priority = $where eq 'up' ? $priority - 1 : $priority + 1;
      _FixPriority({ reserve_id => $reserve_id, rank => $priority })

    } elsif ( $where eq 'top' ) {

      _FixPriority({ reserve_id => $reserve_id, rank => '1' })

    } elsif ( $where eq 'bottom' ) {

      _FixPriority({ reserve_id => $reserve_id, rank => '999999' });

    }
}

=head2 ToggleLowestPriority

  ToggleLowestPriority( $reserve_id );

This function sets the lowestPriority field to true if is false, and false if it is true.

=cut

sub ToggleLowestPriority {
    my ( $reserve_id ) = @_;

    my $dbh = C4::Context->dbh;

    my $sth = $dbh->prepare( "UPDATE reserves SET lowestPriority = NOT lowestPriority WHERE reserve_id = ?");
    $sth->execute( $reserve_id );
    
    _FixPriority({ reserve_id => $reserve_id, rank => '999999' });
}

=head2 ToggleSuspend

  ToggleSuspend( $reserve_id );

This function sets the suspend field to true if is false, and false if it is true.
If the reserve is currently suspended with a suspend_until date, that date will
be cleared when it is unsuspended.

=cut

sub ToggleSuspend {
    my ( $reserve_id, $suspend_until ) = @_;

    $suspend_until = output_pref(
        {
            dt         => dt_from_string($suspend_until),
            dateformat => 'iso',
            dateonly   => 1
        }
    ) if ($suspend_until);

    my $do_until = ( $suspend_until ) ? '?' : 'NULL';

    my $dbh = C4::Context->dbh;

    my $sth = $dbh->prepare(
        "UPDATE reserves SET suspend = NOT suspend,
        suspend_until = CASE WHEN suspend = 0 THEN NULL ELSE $do_until END
        WHERE reserve_id = ?
    ");

    my @params;
    push( @params, $suspend_until ) if ( $suspend_until );
    push( @params, $reserve_id );

    $sth->execute( @params );
}

=head2 SuspendAll

  SuspendAll(
      borrowernumber   => $borrowernumber,
      [ biblionumber   => $biblionumber, ]
      [ suspend_until  => $suspend_until, ]
      [ suspend        => $suspend ]
  );

  This function accepts a set of hash keys as its parameters.
  It requires either borrowernumber or biblionumber, or both.

  suspend_until is wholly optional.

=cut

sub SuspendAll {
    my %params = @_;

    my $borrowernumber = $params{'borrowernumber'} || undef;
    my $biblionumber   = $params{'biblionumber'}   || undef;
    my $suspend_until  = $params{'suspend_until'}  || undef;
    my $suspend        = defined( $params{'suspend'} ) ? $params{'suspend'} :  1;

    $suspend_until = C4::Dates->new( $suspend_until )->output("iso") if ( defined( $suspend_until ) );

    return unless ( $borrowernumber || $biblionumber );

    my ( $query, $sth, $dbh, @query_params );

    $query = "UPDATE reserves SET suspend = ? ";
    push( @query_params, $suspend );
    if ( !$suspend ) {
        $query .= ", suspend_until = NULL ";
    } elsif ( $suspend_until ) {
        $query .= ", suspend_until = ? ";
        push( @query_params, $suspend_until );
    }
    $query .= " WHERE ";
    if ( $borrowernumber ) {
        $query .= " borrowernumber = ? ";
        push( @query_params, $borrowernumber );
    }
    $query .= " AND " if ( $borrowernumber && $biblionumber );
    if ( $biblionumber ) {
        $query .= " biblionumber = ? ";
        push( @query_params, $biblionumber );
    }
    $query .= " AND found IS NULL ";

    $dbh = C4::Context->dbh;
    $sth = $dbh->prepare( $query );
    $sth->execute( @query_params );
}


=head2 _FixPriority

  _FixPriority({
    reserve_id => $reserve_id,
    [rank => $rank,]
    [ignoreSetLowestRank => $ignoreSetLowestRank]
  });

  or

  _FixPriority({ biblionumber => $biblionumber});

This routine adjusts the priority of a hold request and holds
on the same bib.

In the first form, where a reserve_id is passed, the priority of the
hold is set to supplied rank, and other holds for that bib are adjusted
accordingly.  If the rank is "del", the hold is cancelled.  If no rank
is supplied, all of the holds on that bib have their priority adjusted
as if the second form had been used.

In the second form, where a biblionumber is passed, the holds on that
bib (that are not captured) are sorted in order of increasing priority,
then have reserves.priority set so that the first non-captured hold
has its priority set to 1, the second non-captured hold has its priority
set to 2, and so forth.

In both cases, holds that have the lowestPriority flag on are have their
priority adjusted to ensure that they remain at the end of the line.

Note that the ignoreSetLowestRank parameter is meant to be used only
when _FixPriority calls itself.

=cut

sub _FixPriority {
    my ( $params ) = @_;
    my $reserve_id = $params->{reserve_id};
    my $rank = $params->{rank} // '';
    my $ignoreSetLowestRank = $params->{ignoreSetLowestRank};
    my $biblionumber = $params->{biblionumber};

    my $dbh = C4::Context->dbh;

    unless ( $biblionumber ) {
        my $res = GetReserve( $reserve_id );
        $biblionumber = $res->{biblionumber};
    }

    if ( $rank eq "del" ) {
         CancelReserve({ reserve_id => $reserve_id });
    }
    elsif ( $rank eq "W" || $rank eq "0" ) {

        # make sure priority for waiting or in-transit items is 0
        my $query = "
            UPDATE reserves
            SET    priority = 0
            WHERE reserve_id = ?
            AND found IN ('W', 'T')
        ";
        my $sth = $dbh->prepare($query);
        $sth->execute( $reserve_id );
    }
    my @priority;

    # get whats left
    my $query = "
        SELECT reserve_id, borrowernumber, reservedate, constrainttype
        FROM   reserves
        WHERE  biblionumber   = ?
          AND  ((found <> 'W' AND found <> 'T') OR found IS NULL)
        ORDER BY priority ASC
    ";
    my $sth = $dbh->prepare($query);
    $sth->execute( $biblionumber );
    while ( my $line = $sth->fetchrow_hashref ) {
        push( @priority,     $line );
    }

    # To find the matching index
    my $i;
    my $key = -1;    # to allow for 0 to be a valid result
    for ( $i = 0 ; $i < @priority ; $i++ ) {
        if ( $reserve_id == $priority[$i]->{'reserve_id'} ) {
            $key = $i;    # save the index
            last;
        }
    }

    # if index exists in array then move it to new position
    if ( $key > -1 && $rank ne 'del' && $rank > 0 ) {
        my $new_rank = $rank -
          1;    # $new_rank is what you want the new index to be in the array
        my $moving_item = splice( @priority, $key, 1 );
        splice( @priority, $new_rank, 0, $moving_item );
    }

    # now fix the priority on those that are left....
    $query = "
        UPDATE reserves
        SET    priority = ?
        WHERE  reserve_id = ?
    ";
    $sth = $dbh->prepare($query);
    for ( my $j = 0 ; $j < @priority ; $j++ ) {
        $sth->execute(
            $j + 1,
            $priority[$j]->{'reserve_id'}
        );
    }
    
    $sth = $dbh->prepare( "SELECT reserve_id FROM reserves WHERE lowestPriority = 1 ORDER BY priority" );
    $sth->execute();
    
    unless ( $ignoreSetLowestRank ) {
      while ( my $res = $sth->fetchrow_hashref() ) {
        _FixPriority({
            reserve_id => $res->{'reserve_id'},
            rank => '999999',
            ignoreSetLowestRank => 1
        });
      }
    }
}

=head2 _Findgroupreserve

  @results = &_Findgroupreserve($biblioitemnumber, $biblionumber, $itemnumber, $lookahead);

Looks for an item-specific match first, then for a title-level match, returning the
first match found.  If neither, then we look for a 3rd kind of match based on
reserve constraints.
Lookahead is the number of days to look in advance.

TODO: add more explanation about reserve constraints

C<&_Findgroupreserve> returns :
C<@results> is an array of references-to-hash whose keys are mostly
fields from the reserves table of the Koha database, plus
C<biblioitemnumber>.

=cut

sub _Findgroupreserve {
    my ( $bibitem, $biblio, $itemnumber, $lookahead) = @_;
    my $dbh   = C4::Context->dbh;

    # TODO: consolidate at least the SELECT portion of the first 2 queries to a common $select var.
    # check for exact targetted match
    my $item_level_target_query = qq/
        SELECT reserves.biblionumber        AS biblionumber,
               reserves.borrowernumber      AS borrowernumber,
               reserves.reserve_id          AS reserve_id,
               reserves.reservedate         AS reservedate,
               reserves.branchcode          AS branchcode,
               reserves.cancellationdate    AS cancellationdate,
               reserves.found               AS found,
               reserves.reservenotes        AS reservenotes,
               reserves.priority            AS priority,
               reserves.timestamp           AS timestamp,
               biblioitems.biblioitemnumber AS biblioitemnumber,
               reserves.itemnumber          AS itemnumber,
               reserves.reserve_id          AS reserve_id
        FROM reserves
        JOIN biblioitems USING (biblionumber)
        JOIN hold_fill_targets USING (biblionumber, borrowernumber, itemnumber)
        WHERE found IS NULL
        AND priority > 0
        AND item_level_request = 1
        AND itemnumber = ?
        AND reservedate <= DATE_ADD(NOW(),INTERVAL ? DAY)
        AND suspend = 0
    /;
    my $sth = $dbh->prepare($item_level_target_query);
    $sth->execute($itemnumber, $lookahead||0);
    my @results;
    if ( my $data = $sth->fetchrow_hashref ) {
        push( @results, $data );
    }
    return @results if @results;
    
    # check for title-level targetted match
    my $title_level_target_query = qq/
        SELECT reserves.biblionumber        AS biblionumber,
               reserves.borrowernumber      AS borrowernumber,
               reserves.reserve_id          AS reserve_id,
               reserves.reservedate         AS reservedate,
               reserves.branchcode          AS branchcode,
               reserves.cancellationdate    AS cancellationdate,
               reserves.found               AS found,
               reserves.reservenotes        AS reservenotes,
               reserves.priority            AS priority,
               reserves.timestamp           AS timestamp,
               biblioitems.biblioitemnumber AS biblioitemnumber,
               reserves.itemnumber          AS itemnumber,
               reserves.reserve_id          AS reserve_id
        FROM reserves
        JOIN biblioitems USING (biblionumber)
        JOIN hold_fill_targets USING (biblionumber, borrowernumber)
        WHERE found IS NULL
        AND priority > 0
        AND item_level_request = 0
        AND hold_fill_targets.itemnumber = ?
        AND reservedate <= DATE_ADD(NOW(),INTERVAL ? DAY)
        AND suspend = 0
    /;
    $sth = $dbh->prepare($title_level_target_query);
    $sth->execute($itemnumber, $lookahead||0);
    @results = ();
    if ( my $data = $sth->fetchrow_hashref ) {
        push( @results, $data );
    }
    return @results if @results;

    my $query = qq/
        SELECT reserves.biblionumber               AS biblionumber,
               reserves.borrowernumber             AS borrowernumber,
               reserves.reserve_id                 AS reserve_id,
               reserves.reservedate                AS reservedate,
               reserves.waitingdate                AS waitingdate,
               reserves.branchcode                 AS branchcode,
               reserves.cancellationdate           AS cancellationdate,
               reserves.found                      AS found,
               reserves.reservenotes               AS reservenotes,
               reserves.priority                   AS priority,
               reserves.timestamp                  AS timestamp,
               biblioitems.biblioitemnumber        AS biblioitemnumber,
               reserves.itemnumber                 AS itemnumber
        FROM reserves
        JOIN biblioitems USING (biblionumber)
        WHERE reserves.biblionumber = ?
          AND (reserves.constrainttype='a')
          AND (reserves.itemnumber IS NULL OR reserves.itemnumber = ?)
          AND reserves.reservedate <= DATE_ADD(NOW(),INTERVAL ? DAY)
          AND suspend = 0
    /;
    $sth = $dbh->prepare($query);
    $sth->execute( $biblio, $itemnumber, $lookahead||0);
    @results = ();
    while ( my $data = $sth->fetchrow_hashref ) {
        push( @results, $data );
    }
    return @results;
}

=head2 _reserve_last_pickup_date

 my $last_dt = _reserve_last_pickup_date($reserve);

Returns the DateTime for the last pickup date for reserve.

The datetime has a time component of 23:59:59, so the day expires as it should when comparing times as well.
=cut

sub _reserve_last_pickup_date {
    my ($reserve) = @_;

    my $startdate = $reserve->{waitingdate} ? dt_from_string($reserve->{waitingdate}) : DateTime->now( time_zone => C4::Context->tz() );
    my $calendar = Koha::Calendar->new( branchcode => $reserve->{branchcode} );
    my $expiration;

    # Getting the ReservesMaxPickUpDelayBranch
    my $branches = C4::Context->preference("ReservesMaxPickUpDelayBranch");

    my $yaml = YAML::XS::Load(
                        Encode::encode(
                            'UTF-8',
                            $branches,
                            Encode::FB_CROAK
                        )
                    );

    if ($yaml->{$reserve->{branchcode}}) {
        my $delay = $yaml->{$reserve->{branchcode}};
        $expiration = $calendar->days_forward( $startdate, $delay );
    }
    else {
        $expiration = $calendar->days_forward( $startdate, C4::Context->preference('ReservesMaxPickUpDelay') );
    }
       #It is necessary to set the time portion of DateTime as well, because we are actually getting the
       #  last pickup datetime and importantly days end at 23:59:59.
       #  Without this set, last pickup dates expire 1 day too early and frustrates patrons and staff alike!
    $expiration->set( hour       => 23, 
                      minute     => 59,  
                      second     => 59 );

    return $expiration;
}

=head2 _koha_notify_reserve

  _koha_notify_reserve( $itemnumber, $borrowernumber, $biblionumber, $reserve_id );

Sends a notification to the patron that their hold has been filled (through
ModReserveAffect, _not_ ModReserveFill)

=cut

sub _koha_notify_reserve {
    my ($itemnumber, $borrowernumber, $biblionumber, $reserve_id) = @_;

    my $dbh = C4::Context->dbh;
    my $borrower = C4::Members::GetMember(borrowernumber => $borrowernumber);
    
    # Try to get the borrower's email address
    my $to_address = C4::Members::GetNoticeEmailAddress($borrowernumber);

    my $messagingprefs = C4::Members::Messaging::GetMessagingPreferences( {
            borrowernumber => $borrowernumber,
            message_name => 'Hold_Filled'
    } );

    my $sth = $dbh->prepare("
        SELECT *
        FROM   reserves
        WHERE  borrowernumber = ?
            AND biblionumber = ?
            AND reserve_id = ?
    ");
    $sth->execute( $borrowernumber, $biblionumber, $reserve_id );
    my $reserve = $sth->fetchrow_hashref;
    my $branch_details = GetBranchDetail( $reserve->{'branchcode'} );

    my $admin_email_address = $branch_details->{'branchemail'} || C4::Context->preference('KohaAdminEmailAddress');

    my $expiration = _reserve_last_pickup_date($reserve);

    my %letter_params = (
        module => 'reserves',
        branchcode => $reserve->{branchcode},
        tables => {
            'branches'  => $branch_details,
            'borrowers' => $borrower,
            'biblio'    => $biblionumber,
            'reserves'  => $reserve,
            'items', $reserve->{'itemnumber'},
        },
        substitute => {
                    today => C4::Dates->new()->output(),
                    lastpickupdate => C4::Dates->new($expiration->ymd(), 'iso')->output()
        },
    );

    my $notification_sent = 0; #Keeping track if a Hold_filled message is sent. If no message can be sent, then default to a print message.
    my $send_notification = sub {
        my ( $mtt, $letter_code ) = (@_);
        return unless defined $letter_code;
        $letter_params{letter_code} = $letter_code;
        $letter_params{message_transport_type} = $mtt;
        my $letter =  C4::Letters::GetPreparedLetter ( %letter_params );
        unless ($letter) {
            warn "Could not find a letter called '$letter_params{'letter_code'}' for $mtt in the 'reserves' module";
            return;
        }

        C4::Letters::EnqueueLetter( {
            letter => $letter,
            borrowernumber => $borrowernumber,
            from_address => $admin_email_address,
            message_transport_type => $mtt,
        } );
    };

    AddReserveFeeOnNotify($reserve->{'itemnumber'});

    while ( my ( $mtt, $letter_code ) = each %{ $messagingprefs->{transports} } ) {
        if ( ($mtt eq 'email' and not $to_address) or ($mtt eq 'sms' and not $borrower->{smsalertnumber}) ) {
            # email or sms is requested but not exist
            next;
        }
        &$send_notification($mtt, $letter_code);
        $notification_sent++;
    }
    #Making sure that a print notification is sent if no other transport types can be utilized.
    if (! $notification_sent) {
        &$send_notification('print', 'HOLD');
    }
    
}

=head2 _ShiftPriorityByDateAndPriority

  $new_priority = _ShiftPriorityByDateAndPriority( $biblionumber, $reservedate, $priority );

This increments the priority of all reserves after the one
with either the lowest date after C<$reservedate>
or the lowest priority after C<$priority>.

It effectively makes room for a new reserve to be inserted with a certain
priority, which is returned.

This is most useful when the reservedate can be set by the user.  It allows
the new reserve to be placed before other reserves that have a later
reservedate.  Since priority also is set by the form in reserves/request.pl
the sub accounts for that too.

=cut

sub _ShiftPriorityByDateAndPriority {
    my ( $biblio, $new_priority ) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT priority FROM reserves WHERE biblionumber = ? AND priority > ? ORDER BY priority ASC LIMIT 1";
    my $sth = $dbh->prepare( $query );
    $sth->execute( $biblio, $new_priority );
    my $min_priority = $sth->fetchrow;
    # if no such matches are found, $new_priority remains as original value
    $new_priority = $min_priority if ( $min_priority );

    # Shift the priority up by one; works in conjunction with the next SQL statement
    $query = "UPDATE reserves
              SET priority = priority+1
              WHERE reserve_id = ?
              AND found IS NULL";
    my $sth_update = $dbh->prepare( $query );

    # Select all reserves for the biblio with priority greater than $new_priority, and order greatest to least
    $query = "SELECT reserve_id FROM reserves WHERE priority >= ? AND biblionumber = ? ORDER BY priority DESC";
    $sth = $dbh->prepare( $query );
    $sth->execute( $new_priority, $biblio );
    while ( my $row = $sth->fetchrow_hashref ) {
	$sth_update->execute( $row->{reserve_id} );
    }

    return $new_priority;  # so the caller knows what priority they wind up receiving
}

=head2 MoveReserve

  MoveReserve( $itemnumber, $borrowernumber, $cancelreserve )

Use when checking out an item to handle reserves
If $cancelreserve boolean is set to true, it will remove existing reserve

=cut

sub MoveReserve {
    my ( $itemnumber, $borrowernumber, $cancelreserve ) = @_;

    my ( $restype, $res, $all_reserves ) = CheckReserves( $itemnumber );
    return unless $res;

    my $biblionumber     =  $res->{biblionumber};
    my $biblioitemnumber = $res->{biblioitemnumber};

    if ($res->{borrowernumber} == $borrowernumber) {
        ModReserveFill($res);
    }
    else {
        # warn "Reserved";
        # The item is reserved by someone else.
        # Find this item in the reserves

        my $borr_res;
        foreach (@$all_reserves) {
            $_->{'borrowernumber'} == $borrowernumber or next;
            $_->{'biblionumber'}   == $biblionumber   or next;

            $borr_res = $_;
            last;
        }

        if ( $borr_res ) {
            # The item is reserved by the current patron
            ModReserveFill($borr_res);
        }

        if ( $cancelreserve eq 'revert' ) { ## Revert waiting reserve to priority 1
            RevertWaitingStatus({ itemnumber => $itemnumber });
        }
        elsif ( $cancelreserve eq 'cancel' || $cancelreserve ) { # cancel reserves on this item
            CancelReserve({ reserve_id => $res->{'reserve_id'} });
        }
    }
}

=head2 MergeHolds

  MergeHolds($dbh,$to_biblio, $from_biblio);

This shifts the holds from C<$from_biblio> to C<$to_biblio> and reorders them by the date they were placed

=cut

sub MergeHolds {
    my ( $dbh, $to_biblio, $from_biblio ) = @_;
    my $sth = $dbh->prepare(
        "SELECT count(*) as reserve_count FROM reserves WHERE biblionumber = ?"
    );
    $sth->execute($from_biblio);
    if ( my $data = $sth->fetchrow_hashref() ) {

        # holds exist on old record, if not we don't need to do anything
        $sth = $dbh->prepare(
            "UPDATE reserves SET biblionumber = ? WHERE biblionumber = ?");
        $sth->execute( $to_biblio, $from_biblio );

        # Reorder by date
        # don't reorder those already waiting

        $sth = $dbh->prepare(
"SELECT * FROM reserves WHERE biblionumber = ? AND (found <> ? AND found <> ? OR found is NULL) ORDER BY reservedate ASC"
        );
        my $upd_sth = $dbh->prepare(
"UPDATE reserves SET priority = ? WHERE biblionumber = ? AND borrowernumber = ?
        AND reservedate = ? AND constrainttype = ? AND (itemnumber = ? or itemnumber is NULL) "
        );
        $sth->execute( $to_biblio, 'W', 'T' );
        my $priority = 1;
        while ( my $reserve = $sth->fetchrow_hashref() ) {
            $upd_sth->execute(
                $priority,                    $to_biblio,
                $reserve->{'borrowernumber'}, $reserve->{'reservedate'},
                $reserve->{'constrainttype'}, $reserve->{'itemnumber'}
            );
            $priority++;
        }
    }
}

=head2 RevertWaitingStatus

  RevertWaitingStatus({ itemnumber => $itemnumber });

  Reverts a 'waiting' hold back to a regular hold with a priority of 1.

  Caveat: Any waiting hold fixed with RevertWaitingStatus will be an
          item level hold, even if it was only a bibliolevel hold to
          begin with. This is because we can no longer know if a hold
          was item-level or bib-level after a hold has been set to
          waiting status.

=cut

sub RevertWaitingStatus {
    my ( $params ) = @_;
    my $itemnumber = $params->{'itemnumber'};

    return unless ( $itemnumber );

    my $dbh = C4::Context->dbh;

    ## Get the waiting reserve we want to revert
    my $query = "
        SELECT * FROM reserves
        WHERE itemnumber = ?
        AND found IS NOT NULL
        ORDER BY priority
    ";
    my $sth = $dbh->prepare( $query );
    $sth->execute( $itemnumber );
    my $reserve = $sth->fetchrow_hashref();

    ## Increment the priority of all other non-waiting
    ## reserves for this bib record
    $query = "
        UPDATE reserves
        SET
          priority = priority + 1
        WHERE
          biblionumber =  ?
        AND
          priority > 0
    ";
    $sth = $dbh->prepare( $query );
    $sth->execute( $reserve->{'biblionumber'} );

    ## Fix up the currently waiting reserve
    $query = "
    UPDATE reserves
    SET
      priority = 1,
      found = NULL,
      waitingdate = NULL
    WHERE
      reserve_id = ?
    ";
    $sth = $dbh->prepare( $query );
    $sth->execute( $reserve->{'reserve_id'} );
    _FixPriority( { biblionumber => $reserve->{biblionumber} } );
}

=head2 GetReserveId

  $reserve_id = GetReserveId({ biblionumber => $biblionumber, borrowernumber => $borrowernumber [, itemnumber => $itemnumber ] } );

  Returnes the first reserve id that matches the given criteria

=cut

sub GetReserveId {
    my ( $params ) = @_;

    return unless ( ( $params->{'biblionumber'} || $params->{'itemnumber'} ) && $params->{'borrowernumber'} );

    my $dbh = C4::Context->dbh();

    my $sql = "SELECT reserve_id FROM reserves WHERE ";

    my @params;
    my @limits;
    foreach my $key ( keys %$params ) {
        if ( defined( $params->{$key} ) ) {
            push( @limits, "$key = ?" );
            push( @params, $params->{$key} );
        }
    }

    $sql .= join( " AND ", @limits );

    $sql .= " ORDER BY priority";

    my $sth = $dbh->prepare( $sql );
    $sth->execute( @params );
    my $row = $sth->fetchrow_hashref();

    return $row->{'reserve_id'};
}

=head2 GetReserveNextEligible

 GetReserveNextEligible({ biblionumber => $bibnum, borrowernumber => $bornum
                       [, itemnumber => $itemnum ]
                       })

 Returns the next eligible reserve id, or undef.

 If reserve is for a certain item, it is eligible only if it matches the itemnumber.
 If a matching reserve is already waiting, return undef.

=cut

sub GetReserveNextEligible {
    my ( $params ) = @_;

    return unless ( $params->{'biblionumber'} && $params->{'borrowernumber'} );

    my $dbh = C4::Context->dbh();

    my $sql = "SELECT reserve_id, found, itemnumber
                 FROM reserves
                WHERE biblionumber=?
                  AND borrowernumber=?
             ORDER BY priority";

    my $sth = $dbh->prepare( $sql );
    $sth->execute( $params->{'biblionumber'}, $params->{'borrowernumber'} );

    while ( my $row = $sth->fetchrow_hashref() ) {
	next if ($row->{'itemnumber'} && ($row->{'itemnumber'} ne $params->{'itemnumber'}));
	return if ($row->{'found'} =~ /[WF]/); # Waiting or Found(?) are never eligible
	return $row->{'reserve_id'};
    }

    return;
}

=head2 ReserveSlip

  ReserveSlip($branchcode, $borrowernumber, $biblionumber, $itemnumber)

  Returns letter hash ( see C4::Letters::GetPreparedLetter ) or undef

$itemnumber is needed to make sure that the ReserveSlip printing has access to the item in question.
There is a race condition where the slip is printed before the reservation is confirmed to the DB,
thus the reserve target needs to be explicitly passed from the calling module if such a race condition is encoutered.
Otherwise $itemnumber is pulled properly from the reserves-table.
=cut

sub ReserveSlip {
    my ($branch, $borrowernumber, $biblionumber, $transfer, $reserve_id, $itemnumber) = @_;

#   return unless ( C4::Context->boolean_preference('printreserveslips') );

    $reserve_id = GetReserveId({
        biblionumber => $biblionumber,
        borrowernumber => $borrowernumber
    }) or return unless $reserve_id;
    my $reserve = GetReserveInfo($reserve_id) or return;

    $reserve->{itemnumber} = $itemnumber if (not($reserve->{itemnumber}) && $itemnumber);

    my $expiration = _reserve_last_pickup_date($reserve);

    return  C4::Letters::GetPreparedLetter (
        module => 'circulation',
        letter_code => $transfer ? 'TRANSFERSLIP' : 'RESERVESLIP',
        branchcode => $branch,
        tables => {
            'reserves'    => $reserve,
            'branches'    => $reserve->{branchcode},
            'borrowers'   => $reserve->{borrowernumber},
            'biblio'      => $reserve->{biblionumber},
            'items'       => $reserve->{itemnumber},
        },
        substitute => {
            lastpickupdate => C4::Dates->new($expiration->ymd(), 'iso')->output()
        },
    );
}

=head2 GetReservesControlBranch

  my $reserves_control_branch = GetReservesControlBranch($item, $borrower);

  Return the branchcode to be used to determine which reserves
  policy applies to a transaction.

  C<$item> is a hashref for an item. Only 'homebranch' is used.

  C<$borrower> is a hashref to borrower. Only 'branchcode' is used.

=cut

sub GetReservesControlBranch {
    my ( $item, $borrower ) = @_;

    my $reserves_control = C4::Context->preference('ReservesControlBranch');

    my $branchcode =
        ( $reserves_control eq 'ItemHomeLibrary' ) ? $item->{'homebranch'}
      : ( $reserves_control eq 'PatronLibrary' )   ? $borrower->{'branchcode'}
      :                                              undef;

    return $branchcode;
}

=head2 CalculatePriority

    my $p = CalculatePriority($biblionumber, $resdate);

Calculate priority for a new reserve on biblionumber, placing it at
the end of the line of all holds whose start date falls before
the current system time and that are neither on the hold shelf
or in transit.

The reserve date parameter is optional; if it is supplied, the
priority is based on the set of holds whose start date falls before
the parameter value.

After calculation of this priority, it is recommended to call
_ShiftPriorityByDateAndPriority. Note that this is currently done in
AddReserves.

=cut

sub CalculatePriority {
    my ( $biblionumber, $resdate ) = @_;

    my $sql = q{
        SELECT COUNT(*) FROM reserves
        WHERE biblionumber = ?
        AND   priority > 0
        AND   (found IS NULL OR found = '')
    };
    #skip found==W or found==T (waiting or transit holds)
    if( $resdate ) {
        $sql.= ' AND ( reservedate <= ? )';
    }
    else {
        $sql.= ' AND ( reservedate < NOW() )';
    }
    my $dbh = C4::Context->dbh();
    my @row = $dbh->selectrow_array(
        $sql,
        undef,
        $resdate ? ($biblionumber, $resdate) : ($biblionumber)
    );

    return @row ? $row[0]+1 : 1;
}

=head printReserve

    my $text = C4::Reserves::printReserve( $reserve, 'tab', ['reserve_id','borrowernumber','waitingdate', ...] );
    assert($text, "         1|       1017466| 2014-11-06| ...");

Gets a textual representation of a koha.reserves -row.

@PARAM1 koha.reserves-row
@PARAM2 String, type of formatting, currently supported are 'tab' to print tabular output.
        Defaults the column width to the key length.
@PARAM3 Array of columns, the desired reserves-columns to output in the given order.
RETURNS String, depending on the type of formatting.

=cut

sub printReserve {
    my ($reserve, $format, $keys) = @_;
    my @sb;

    if ($format eq 'tab') {
        foreach my $key (@$keys) {
            my $l = length $key;
            push @sb, sprintf('% '.$l.'s', $reserve->{$key}).'|';
        }
        return join('',@sb);
    }
}

=head2 AddReserveFeeOnNotify

  AddReserveFeeOnNotify( $itemnumber, $permanent_location )

  #Kyyti#993, adds reserve fee when notifying the patron. 

=cut

sub AddReserveFeeOnNotify {
    my ($itemnumber) = @_;
    my @zeroLocations = split( /\|/, C4::Context->preference("ReserveFeeOnNotify") );
    if (@zeroLocations) {
        my $dbh = C4::Context->dbh;
        my ( $restype, $res ) = C4::Reserves::CheckReserves( $itemnumber );
        my $item = GetBiblioFromItemNumber($itemnumber, undef);
        my $fee;
        my $checked = 0;
        foreach my $location (@zeroLocations) {
            my $isth = $dbh->prepare("SELECT * FROM items WHERE itemnumber = ? and permanent_location = ?");
            $isth->execute($itemnumber, $location);
            if (my $idata = $isth->fetchrow_hashref && $location ne 'null') {
                warn "Don't add any fee\n";
                $fee = 0;
                return;
            } else {
                $checked = 1;
            }
        }
        if ( $checked) {
            warn "Adding borrower's hold fee\n";
            my $query = qq/
              SELECT * FROM borrowers
            LEFT JOIN categories ON borrowers.categorycode = categories.categorycode
            WHERE borrowernumber = ?
            /;
            my $sth = $dbh->prepare($query);
            $sth->execute($res->{'borrowernumber'});
            my $data = $sth->fetchrow_hashref;
            $fee      = $data->{'reservefee'};
            if ($fee > 0) {
                #eval {
                # updates take place here
                    my $nextacctno = &getnextacctno( $res->{'borrowernumber'} );
                    my $query      = qq/
                    INSERT INTO accountlines
                        (borrowernumber,accountno,date,amount,description,accounttype,amountoutstanding)
                    VALUES
                        (?,?,now(),?,?,'Res',?)
                /;
                    my $usth = $dbh->prepare($query);
                    my $asth = $dbh->prepare("SELECT * FROM accountlines WHERE borrowernumber = ? and 
                        amount = ? and description = ? and accounttype = 'RES' and (amountoutstanding = ? or amountoutstanding = 0.00)");
                    $asth->execute($res->{'borrowernumber'}, $fee, "Reserve Charge - $item->{title}", $fee);
                    unless (my $adata = $asth->fetchrow_hashref) {
                        $usth->execute( $res->{'borrowernumber'}, $nextacctno, $fee,
                        "Reserve Charge - $item->{title}", $fee );
                    }
                    
            }
        }
    }
    return;
}



=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut

1;
