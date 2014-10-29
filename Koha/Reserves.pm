package Koha::Reserves;

# Copyright (c) 2014 Vaarakirjastot.fi and everybody else!
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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
    # set the version for version checking
    $VERSION = 3.16.3;
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw(

        &GetLastpickupdate
        &GetWaitingReserves
    );
}    

use C4::Context;
use Koha::DateUtils;
use Koha::Database;

=head2 GetLastpickupdate

 my $last_dt = GetLastpickupdate($reserve);

@PARAM1 Koha::Schema::Result::Reserve-object received via DBIx searching
@RETURNS the DateTime for the last pickup date for the given reserve.
=cut

sub GetLastpickupdate {
    my ($reserve) = @_;

    my $branchcode = $reserve->branchcode();
    if (ref $branchcode eq 'Koha::Schema::Result::Branch') {
        $branchcode = $branchcode->branchcode();
    }

    my $waitingdate = $reserve->waitingdate();
    my $startdate = $waitingdate ? Koha::DateUtils::dt_from_string($waitingdate) : DateTime->now( time_zone => C4::Context->tz() );
    my $calendar = Koha::Calendar->new( branchcode => $branchcode );
    my $expiration;
    if ($branchcode eq 'JOE_LIPAU' ||
        $branchcode eq 'JOE_KONAU' ||
        $branchcode eq 'JOE_JOEAU' ) {
        $expiration = $calendar->days_forward( $startdate, 10 );
    }
    else {
        $expiration = $calendar->days_forward( $startdate, C4::Context->preference('ReservesMaxPickUpDelay') );
    }

    return $expiration;
}

=head2 GetWaitingReserves

  my $waitingReserves = GetWaitingReserves($borrowernumber);
  
@PARAM1 Integer from koha.borrowers.borrowernumber
@RETURNS DBIx:: containing Reservation-objects.
=cut
sub GetWaitingReserves {
    my ($borrowernumber) = @_;
    
    my $schema = Koha::Database->new()->schema();
    my $reserves_rs = $schema->resultset('Reserve')->search(
        { -and => [
               borrowernumber => $borrowernumber,
               found => 'W'
            ]
        },
        {
            prefetch => { 'item'  =>  'biblio' },
        }
    );

    my $currentBranch = C4::Context->userenv->{branch};

    my @waitingReserves;
    while ( my $reserve = $reserves_rs->next() ) {
        my %waitingReserveInfo;

        my $lastpickupdate = Koha::Reserves::GetLastpickupdate( $reserve );
        $lastpickupdate = C4::Dates->new($lastpickupdate->ymd(), 'iso')->output();

        my $pickupBranchcode = $reserve->branchcode();
        my $pickupBranch;
        if (ref $pickupBranchcode eq 'Koha::Schema::Result::Branch') {
            $pickupBranch = $pickupBranchcode;
            $pickupBranchcode = $pickupBranchcode->branchcode();
        }

        my $biblio = $reserve->biblio();
        if ($biblio) { #For some reason it is possible for a waiting hold to not have a biblio?
            $waitingReserveInfo{title}          = $biblio->title();
            $waitingReserveInfo{biblionumber}   = $biblio->biblionumber();
            $waitingReserveInfo{author}         = $biblio->author();
        }
        else {
            $waitingReserveInfo{title}          = "<<ERROR, no biblio found>>";
        }

        $waitingReserveInfo{lastpickupdate} = $lastpickupdate;

        my $item = $reserve->item();
        if ($item) {
            $waitingReserveInfo{itemcallnumber} = $reserve->item()->itemcallnumber();
        }
        else {
            $waitingReserveInfo{itemcallnumber} = "<<ERROR, no item found>>";
        }

        #$waitingReserveInfo{itemcallnumber} = $reserve->item()->itemcallnumber();
        $waitingReserveInfo{waitinghere}    = 1 if $pickupBranchcode eq $currentBranch;
        $waitingReserveInfo{waitingat}      = $pickupBranch->branchname();

        push @waitingReserves, \%waitingReserveInfo;
    }
    return \@waitingReserves;
}

return 1;
