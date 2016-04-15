#!/usr/bin/perl

# Copyright KohaSuomi 2016
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

use Koha::BiblioDataElements;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('KD-257-3')) {
    $dbh->do(q{ALTER TABLE biblio_data_elements ADD COLUMN encoding_level varchar(1);});
    $dbh->do(q{ALTER TABLE biblio_data_elements ADD KEY `encoding_level` (`encoding_level`);});
    Koha::BiblioDataElements::markForReindex();
    print "Upgrade done (KD-257-3 - Add 'Encoding level' to the Biblio data elements -table)\n";
}
