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

unless($atomicUpdater->find('Bug1380')) {

    $dbh->do("INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('ReservesMaxPickUpDelayBranch', '', '', 'Add reserve max pickup delay for individual branches.', 'Textarea')");
    if ($dbh->errstr)
	{
	  die "Could not do insert: Remove #1380 from atomicupdate table and fix query (Bug1380: Add reserve max pickup delay for individual branches.)\n";

	}

    print "Upgrade done (Bug1380: Add reserve max pickup delay for individual branches.)\n";
}