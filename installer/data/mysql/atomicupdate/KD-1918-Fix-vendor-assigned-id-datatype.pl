use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

# This is only needed with older versio of KD-1530 that sets vendor_assigned_id datatype to integer!
# The script is only here to fix procurement_bookseller_links tables created with older atomicupdate-script.

unless ($atomicUpdater->find('KD1918-Fix-vendor-assigned-id-datatype')) {

    $dbh->do(q{
      ALTER TABLE procurement_bookseller_link MODIFY vendor_assigned_id VARCHAR(20) NOT NULL;
    });

    print "Upgrade done (KD1918-Fix-vendor-assigned-id-datatype)\n";
}
