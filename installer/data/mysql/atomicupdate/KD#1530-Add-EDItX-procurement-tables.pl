use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless ($atomicUpdater->find('KD#1530-Add-EDItX-procurement-tables')) {

    $dbh->do(q{
        CREATE TABLE procurement_bookseller_link (
        aqbooksellers_id INT(11) NOT NULL,
        vendor_assigned_id BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY (aqbooksellers_id, vendor_assigned_id),
        KEY ix_procurement_bookseller_link_aqbooksellers_id (aqbooksellers_id),
        KEY ix_procurement_bookseller_link_vendor_assigned_id (vendor_assigned_id),
        FOREIGN KEY (aqbooksellers_id) REFERENCES aqbooksellers(id)
        ON DELETE CASCADE ON UPDATE CASCADE 
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE procurement_file (
        file_id INT(11) NOT NULL AUTO_INCREMENT,
        file_name VARCHAR(255) NOT NULL,
        file_hash VARCHAR(255) NOT NULL,
        PRIMARY KEY (file_id),
        UNIQUE KEY ix_procurement_file_file_name_file_hash (file_name, file_hash)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE `map_productform` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `onix_code` varchar(5) DEFAULT NULL,
        `productform` varchar(5) DEFAULT NULL,
        PRIMARY KEY (`id`)
        ) ENGINE=InnoDB AUTO_INCREMENT=129 DEFAULT CHARSET=latin1;
    });

    # Default itemtype mappings ONIX->ITYPE

    $dbh->do(q{
        INSERT INTO map_productform (onix_code,productform) VALUES
            ('AA','CD'),
            ('AB','KA'),
            ('AC','CD'),
            ('AD','KA'),
            ('AE','KI'),
            ('AF','KI'),
            ('AG','KI'),
            ('AH','KI'),
            ('AI','DV'),
            ('AJ','KI'),
            ('AK','KI'),
            ('AL','KI'),
            ('AZ','KI'),
            ('BA','KI'),
            ('BB','KI'),
            ('BC','KI'),
            ('BD','KI'),
            ('BE','KI'),
            ('BF','KI'),
            ('BG','KI'),
            ('BH','KI'),
            ('BI','KI'),
            ('BJ','KI'),
            ('BK','KI'),
            ('BL','KI'),
            ('BM','KI'),
            ('BN','KI'),
            ('BO','KI'),
            ('BP','KI'),
            ('BZ','KI'),
            ('CA','KR'),
            ('CB','KR'),
            ('CC','KR'),
            ('CD','KR'),
            ('CE','ES'),
            ('CZ','KR'),
            ('DA','KI'),
            ('DB','CR'),
            ('DC','CR'),
            ('DD','DV'),
            ('DE','KI'),
            ('DF','KI'),
            ('DG','EK'),
            ('DH','VA'),
            ('DI','KI'),
            ('DJ','KI'),
            ('DK','KI'),
            ('DL','KI'),
            ('DM','KI'),
            ('DN','KI'),
            ('DO','KI'),
            ('DZ','KI'),
            ('FA','KI'),
            ('FB','KI'),
            ('FC','KI'),
            ('FD','KI'),
            ('FE','KI'),
            ('FF','KI'),
            ('FZ','KI'),
            ('MA','MF'),
            ('MB','MF'),
            ('MC','MF'),
            ('MZ','MF'),
            ('PA','KI'),
            ('PB','KI'),
            ('PC','KI'),
            ('PD','KI'),
            ('PE','KI'),
            ('PF','KI'),
            ('PG','KI'),
            ('PH','KI'),
            ('PI','NU'),
            ('PJ','KI'),
            ('PK','KI'),
            ('PL','KI'),
            ('PM','KI'),
            ('PN','KI'),
            ('PO','KI'),
            ('PP','KI'),
            ('PQ','KI'),
            ('PR','KI'),
            ('PS','KI'),
            ('PT','KI'),
            ('PZ','KI'),
            ('VA','VV'),
            ('VB','VV'),
            ('VC','VV'),
            ('VD','VV'),
            ('VE','VV'),
            ('VF','KI'),
            ('VG','VV'),
            ('VH','VV'),
            ('VI','DV'),
            ('VJ','VV'),
            ('VK','KI'),
            ('VL','KI'),
            ('VM','KI'),
            ('VN','KI'),
            ('VO','BR'),
            ('VP','KI'),
            ('VZ','KI'),
            ('WW','MV'),
            ('WX','KI'),
            ('XA','KI'),
            ('XB','KI'),
            ('XC','KI'),
            ('XD','KI'),
            ('XE','KI'),
            ('XF','KI'),
            ('XG','KI'),
            ('XH','KI'),
            ('XI','KI'),
            ('XJ','KI'),
            ('XK','KI'),
            ('XL','KI'),
            ('XZ','KI'),
            ('ZA','KI'),
            ('ZB','ES'),
            ('ZC','ES'),
            ('ZD','ES'),
            ('ZE','PE'),
            ('ZF','ES'),
            ('ZG','ES'),
            ('ZH','ES'),
            ('ZI','ES'),
            ('ZJ','ES'),
            ('ZY','ES'),
            ('ZZ','KI');
    });

    print "Upgrade done (KD#1530-Add-EDItX-procurement-tables)\n";
}
