#!/usr/bin/perl

# Copyright Open Source Freedom Fighters
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

use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('Bug10744')) {

    $dbh->do("ALTER TABLE reserves ADD `pickupexpired` DATE DEFAULT NULL AFTER `expirationdate`");
    $dbh->do("ALTER TABLE reserves ADD KEY `reserves_pickupexpired` (`pickupexpired`)");
    $dbh->do("ALTER TABLE old_reserves ADD `pickupexpired` DATE DEFAULT NULL AFTER `expirationdate`");
    $dbh->do("ALTER TABLE old_reserves ADD KEY `old_reserves_pickupexpired` (`pickupexpired`)");

    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('PickupExpiredHoldsOverReportDuration','1',NULL,\"For how many days holds expired by the 'ExpireReservesMaxPickUpDelay'-syspref are visible in the 'Hold Over'-tab in /circ/waitingreserves.pl ?\",'Integer')");

    print "Upgrade done (Bug 10744 - ExpireReservesMaxPickUpDelay has minor workflow conflicts with hold(s) over report)\n";
}
