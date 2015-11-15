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
use C4::Serials;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('Bug15191')) {
    print "Starting upgrade (Bug 15191 - Serials improavaments). This might take a while.\n";

    $dbh->do("ALTER TABLE serial ADD COLUMN pattern_x varchar(6)");
    $dbh->do("ALTER TABLE serial ADD COLUMN pattern_y varchar(6)");
    $dbh->do("ALTER TABLE serial ADD COLUMN pattern_z varchar(6)");
    $dbh->do("ALTER TABLE serial ADD INDEX (pattern_x)");
    $dbh->do("ALTER TABLE serial ADD INDEX (pattern_y)");
    $dbh->do("ALTER TABLE serial ADD INDEX (pattern_z)");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('UseBetaFeatures','0',NULL,'Use beta features?','YesNo')");

    C4::Serials::updatePatternsXYZ({verbose => 0, serialSequenceSplitterRegexp => ':'});

    print "Upgrade done (Bug 15191 - Serials improavaments)\n";
}
