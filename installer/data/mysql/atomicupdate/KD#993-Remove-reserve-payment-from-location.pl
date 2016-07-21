#!/usr/bin/perl

# Copyright Koha-Suomi Oy
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

unless($atomicUpdater->find('#993')) {

    $dbh->do("INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('ReserveFeeOnNotify', '', '', Add reserve fee to patrons fines when sending notify message and remove payment from certain locations.', 'Choice')");
    if ($dbh->errstr)
	{
	  die "Could not do insert: Remove #993 from atomicupdate table and fix query (KD#993: Add reserve fee to patron's fines when sending notify message and remove payment from certain locations.)\n";

	}

    print "Upgrade done (KD#993: Add reserve fee to patron's fines when sending notify message and remove payment from certain locations.)\n";
}