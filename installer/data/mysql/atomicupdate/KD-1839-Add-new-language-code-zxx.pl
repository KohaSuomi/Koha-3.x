#!/usr/bin/perl

# Copyright Koha-Suomi Oy 2017
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

unless($atomicUpdater->find('KD-1839')) {
    # No linguistic information
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'zxx', 'language', 'No linguistic information',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'zxx', 'zxx')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'zxx', 'language', 'en', 'No linguistic information')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'zxx', 'language', 'zxx', 'No linguistic information')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'zxx', 'language', 'fi', 'Ei kielellistä sisältöä')");

    print "Upgrade done (KD-1839: Add new language code zxx - no linguistic information)\n";
}
