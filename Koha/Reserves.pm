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
binmode STDOUT, ":encoding(UTF-8)";
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
    my $expiration = $calendar->days_forward( $startdate, C4::Context->preference('ReservesMaxPickUpDelay') );

    return $expiration;
}



return 1;