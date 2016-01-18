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

unless($atomicUpdater->find('KD613')) {

    use Koha::Auth::PermissionManager;
    my $pm = Koha::Auth::PermissionManager->new();
    $pm->addPermissionModule({module => 'labels', description => 'Permissions related to getting all kinds of labels to bibliographic items'});
    $pm->addPermission({module => 'labels', code => 'sheets_get', description => 'Allow viewing all label sheets'});
    $pm->addPermission({module => 'labels', code => 'sheets_new', description => 'Allow creating all label sheets'});
    $pm->addPermission({module => 'labels', code => 'sheets_mod', description => 'Allow modifying all label sheets'});
    $pm->addPermission({module => 'labels', code => 'sheets_del', description => 'Allow deleting all label sheets'});

$dbh->do(
"CREATE TABLE `label_sheets` (".
"  `id`   int(11) NOT NULL,".
"  `name` varchar(100) NOT NULL,".
"  `author` int(11) DEFAULT NULL,".
"  `version` float(4,1) NOT NULL,".
"  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,".
"  `sheet` MEDIUMTEXT NOT NULL,".
"  KEY  (`id`),".
"  UNIQUE KEY `id_version` (`id`, `version`),".
"  KEY `name` (`name`),".
"  CONSTRAINT `labshet_authornumber` FOREIGN KEY (`author`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE SET NULL ON UPDATE CASCADE".
") ENGINE=InnoDB DEFAULT CHARSET=utf8;"
);

    print "Upgrade done (KD-613: Labels GUI editor and printer)\n";
}
