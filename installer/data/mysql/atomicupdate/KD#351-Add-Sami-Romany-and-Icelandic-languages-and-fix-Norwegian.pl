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

unless($atomicUpdater->find('#351')) {
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'smi', 'language', 'Sami',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'smi', 'smi')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'smi', 'language', 'en', 'Sami')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'smi', 'language', 'smi', 'Sami')");

    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'rom', 'language', 'Romany',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'rom', 'rom')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'rom', 'language', 'en', 'Romany')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'rom', 'language', 'rom', 'romani ćhib')");
    
    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'rom', 'language', 'fi', 'romanikieli')");
    
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'is', 'language', 'Icelandic',NOW())");

    $dbh->do("INSERT INTO language_rfc4646_to_iso639(rfc4646_subtag,iso639_2_code)
    VALUES( 'is', 'ice')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'is', 'language', 'en', 'Icelandic')");

    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'is', 'language', 'is', 'íslenska')");
    
    # Add Norwegian (nor) NOTE
    # Norwegian already exists in two forms:
    # nob = Norwegian bokmål
    # nno = Norwegian nynorsk
    # This patch also adds nor = Norwegian
    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'no', 'language', 'en', 'Norwegian')");
    
    $dbh->do("INSERT INTO language_descriptions(subtag, type, lang, description)
    VALUES( 'no', 'language', 'no', 'norsk')");
    
    $dbh->do("INSERT INTO language_subtag_registry( subtag, type, description, added)
    VALUES( 'no', 'language', 'Norwegian',NOW())");

    $dbh->do("UPDATE language_rfc4646_to_iso639 SET rfc4646_subtag='no' WHERE iso639_2_code='nor'");
    
    print "Upgrade done (KD#351: Add Sami, Romany and Icelandic and Norwegian (nor) languages)\n";
}

