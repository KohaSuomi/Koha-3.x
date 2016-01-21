#!/usr/bin/perl

# Copyright KohaSuomi
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

unless($atomicUpdater->find('KD257')) {
    $dbh->do(q{
        CREATE TABLE `biblio_data_elements` (
          `id` int(12) NOT NULL auto_increment, -- stores extracted MARC key indicators for easy access.
          `biblioitemnumber` int(11) NOT NULL, -- References the biblioitems.biblioitemnumber, but is not a foreign key reference because of cascading issues.
          `last_mod_time` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP, -- date and time this record was last touched
          `deleted` tinyint(1) default NULL, -- Boolean indicating whether the biblio is deleted, and is the biblioitem found from koha.deletedbiblioitems or koha.biblioitems.
          `primary_language` varchar(3) NOT NULL default '', -- primary language code from 041$a
          `languages` varchar(40) NOT NULL default '', -- language codes concatenated. [<subfield><code>...] Eg. aFINbSVEcNOR
          `fiction` tinyint(1) default NULL, -- Boolean indicating whether the biblio is considered fiction
          `musical` tinyint(1) default NULL, -- Boolean indicating whether the biblio is considered to be a musical recording
          `itemtype` varchar(10) default NULL, -- biblio level item type (MARC21 942$c)
          `serial` tinyint(1) default NULL, -- Boolean indicating whether the biblio is a serial
          PRIMARY KEY  (`id`),
          UNIQUE KEY `bibitnoidx` (`biblioitemnumber`),
          KEY `last_mod_time` (`last_mod_time`),
          KEY bde_fiction_idx (fiction),
          KEY bde_serial_idx (serial),
          KEY bde_musical_idx (musical),
          KEY bde_primary_language_idx (primary_language)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    });
    print "Upgrade done (KD-257 - Precalculated Biblio data elements -table)\n";
}
