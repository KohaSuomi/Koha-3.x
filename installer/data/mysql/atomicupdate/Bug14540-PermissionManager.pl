use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless ($atomicUpdater->find('Bug14540')) {
    ##CREATE new TABLEs
    ##CREATing instead of ALTERing existing tables because this way the changes are more easy to understand.
    $dbh->do("CREATE TABLE permission_modules (
                permission_module_id int(11) NOT NULL auto_increment,
                module varchar(32) NOT NULL,
                description varchar(255) DEFAULT NULL,
                PRIMARY KEY  (permission_module_id),
                UNIQUE KEY (module)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh->do("INSERT INTO permission_modules (permission_module_id, module, description) SELECT bit, flag, flagdesc FROM userflags WHERE bit != 0;"); #superlibrarian causes primary key conflict
    $dbh->do("INSERT INTO permission_modules (permission_module_id, module, description) SELECT 21, flag, flagdesc FROM userflags WHERE bit = 0;");   #So add him by himself.

    $dbh->do("ALTER TABLE permissions RENAME TO permissions_old");
    $dbh->do("CREATE TABLE permissions (
                permission_id int(11) NOT NULL auto_increment,
                module varchar(32) NOT NULL,
                code varchar(64) NOT NULL,
                description varchar(255) DEFAULT NULL,
                PRIMARY KEY  (permission_id),
                UNIQUE KEY (code),
                CONSTRAINT permissions_to_modules_ibfk1 FOREIGN KEY (module) REFERENCES permission_modules (module)
                  ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh->do("INSERT INTO permissions (module, code, description)
                SELECT userflags.flag, code, description FROM permissions_old
                  LEFT JOIN userflags ON permissions_old.module_bit = userflags.bit;");

    $dbh->do("CREATE TABLE borrower_permissions (
                borrower_permission_id int(11) NOT NULL auto_increment,
                borrowernumber int(11) NOT NULL,
                permission_module_id int(11) NOT NULL,
                permission_id int(11) NOT NULL,
                PRIMARY KEY  (borrower_permission_id),
                UNIQUE KEY (borrowernumber, permission_module_id, permission_id),
                CONSTRAINT borrower_permissions_ibfk_1 FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber)
                  ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT borrower_permissions_ibfk_2 FOREIGN KEY (permission_id) REFERENCES permissions (permission_id)
                  ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT borrower_permissions_ibfk_3 FOREIGN KEY (permission_module_id) REFERENCES permission_modules (permission_module_id)
                  ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh->do("INSERT INTO borrower_permissions (borrowernumber, permission_module_id, permission_id)
                SELECT user_permissions.borrowernumber, user_permissions.module_bit, permissions.permission_id
                FROM user_permissions
                LEFT JOIN permissions ON user_permissions.code = permissions.code
                LEFT JOIN borrowers ON borrowers.borrowernumber = user_permissions.borrowernumber
                WHERE borrowers.borrowernumber IS NOT NULL;"); #It is possible to have user_permissions dangling around not pointing to anything, so make sure we dont try to move nonexisting borrower permissions.

    ##Add subpermissions to the stand-alone modules (modules with no subpermissions)
    $dbh->do("INSERT INTO permissions (module, code, description) VALUES ('superlibrarian', 'superlibrarian', 'Access to all librarian functions.');");
    $dbh->do("INSERT INTO permissions (module, code, description) VALUES ('catalogue', 'staff_login', 'Allow staff login.');");
    $dbh->do("INSERT INTO permissions (module, code, description) VALUES ('borrowers', 'view_borrowers', 'Show borrower details and search for borrowers.');");
    $dbh->do("INSERT INTO permissions (module, code, description) VALUES ('permissions', 'set_permissions', 'Set user permissions.');");
    $dbh->do("INSERT INTO permissions (module, code, description) VALUES ('management', 'management', 'Set library management parameters (deprecated).');");
    $dbh->do("INSERT INTO permissions (module, code, description) VALUES ('editauthorities', 'edit_authorities', 'Edit authorities.');");
    $dbh->do("INSERT INTO permissions (module, code, description) VALUES ('staffaccess', 'staff_access_permissions', 'Allow staff members to modify permissions for other staff members.');");

    ##Create borrower_permissions to replace singular userflags from borrowers.flags.
    my $sthSelectAllBorrowers = $dbh->prepare("SELECT * FROM borrowers;");
    my $sth = $dbh->prepare("
            INSERT INTO borrower_permissions (borrowernumber, permission_module_id, permission_id)
            VALUES (?,
                    (SELECT permission_module_id FROM permission_modules WHERE module = ?),
                    (SELECT permission_id FROM permissions WHERE code = ?)
                   );
            ");
    $sthSelectAllBorrowers->execute();
    my $borrowers = $sthSelectAllBorrowers->fetchall_arrayref({});
    foreach my $b (@$borrowers) {
        next unless $b->{flags};
        if ( ( $b->{flags} & ( 2**0 ) ) ) {
            $sth->execute($b->{borrowernumber}, 'superlibrarian', 'superlibrarian');
        }
        if ( ( $b->{flags} & ( 2**2 ) ) ) {
            $sth->execute($b->{borrowernumber}, 'catalogue', 'staff_login');
        }
        if ( ( $b->{flags} & ( 2**4 ) ) ) {
            $sth->execute($b->{borrowernumber}, 'borrowers', 'view_borrowers');
        }
        if ( ( $b->{flags} & ( 2**5 ) ) ) {
            $sth->execute($b->{borrowernumber}, 'permissions', 'set_permissions');
        }
        if ( ( $b->{flags} & ( 2**12 ) ) ) {
            $sth->execute($b->{borrowernumber}, 'management', 'management');
        }
        if ( ( $b->{flags} & ( 2**14 ) ) ) {
            $sth->execute($b->{borrowernumber}, 'editauthorities', 'edit_authorities');
        }
        if ( ( $b->{flags} & ( 2**17 ) ) ) {
            $sth->execute($b->{borrowernumber}, 'staffaccess', 'staff_access_permissions');
        }
    }

    ##Cleanup redundant tables.
    $dbh->do("DELETE FROM userflags"); #Cascades to other tables.
    $dbh->do("DROP TABLE user_permissions");
    $dbh->do("DROP TABLE permissions_old");
    $dbh->do("DROP TABLE userflags");
    $dbh->do("ALTER TABLE borrowers DROP COLUMN flags");
    $dbh->do("DELETE FROM permission_modules WHERE module = 'borrow'");

    print "Upgrade done (Bug 14540 - Move member-flags.pl to PermissionsManager to better manage permissions for testing.)\n";
}
