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

unless($atomicUpdater->find('#70')) {
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'et', 'language', 'Estonian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'et', 'est')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'et', 'language', 'en', 'Estonian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'et', 'language', 'et', 'Eesti')");

    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'krl', 'language', 'Karelian',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'krl', 'krl')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'krl', 'language', 'en', 'Karelian')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'krl', 'language', 'krl', 'Karjala')");
    print "Upgrade done (KD#70: Add Estonian and Karelian languages)\n";
}
