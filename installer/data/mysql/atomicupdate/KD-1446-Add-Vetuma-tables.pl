use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless ($atomicUpdater->find('KD#1446-Add-Vetuma-tables')) {

    $dbh->do(q{
        CREATE TABLE vetuma_transaction (
            transaction_id  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            amount  DECIMAL(28,6) NULL,
            request_timestamp  BIGINT UNSIGNED NULL,
            response_timestamp  BIGINT UNSIGNED NULL,
            ref VARCHAR(255) NULL,
            trid VARCHAR(255) NULL,
            response_so VARCHAR(255) NULL,
            payid VARCHAR(255) NULL,
            paid VARCHAR(255) NULL,
            status VARCHAR(255) NULL,
            PRIMARY KEY (transaction_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    });

    $dbh->do(q{
        CREATE TABLE vetuma_transaction_accountlines_link (
            accountlines_id  INT(11) NOT NULL,
            transaction_id  BIGINT UNSIGNED NOT NULL,
            PRIMARY KEY (accountlines_id, transaction_id),
            KEY ix_vetuma_transaction_link_accountlines_id (accountlines_id),
            KEY ix_vetuma_transaction_link_transaction_id (transaction_id), 
            FOREIGN KEY (accountlines_id) REFERENCES accountlines(accountlines_id)
                ON DELETE CASCADE ON UPDATE CASCADE,
            FOREIGN KEY (transaction_id) REFERENCES vetuma_transaction(transaction_id)
                ON DELETE CASCADE ON UPDATE CASCADE  
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    });

    print "Upgrade done (KD#1446-Add-Vetuma-tables)\n";
}
