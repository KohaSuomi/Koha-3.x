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

unless($atomicUpdater->find('Bug11629')) {

    $dbh->do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES('UpdateNotForLoanStatusOnCheckin', '', 'NULL', 'This is a list of value pairs. When an item is checked in, if the not for loan value on the left matches the items not for loan value it will be updated to the right-hand value. E.g. ''-1: 0'' will cause an item that was set to ''Ordered'' to now be available for loan. Each pair of values should be on a separate line.', 'Free');");

    print "Upgrade done (Bug 11629 - Add ability to update not for loan status on checkin)\n";
}
