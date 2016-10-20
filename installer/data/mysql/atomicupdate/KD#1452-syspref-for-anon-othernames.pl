use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless ($atomicUpdater->find('KD#1452-syspref-for-anon-othernames')) {

    $dbh->do(
        "INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('AnonymizeOthernames', '0', null, 'If set, anonymize borrowers holds identifiers when adding new borrowers', 'YesNo');"
    );

    print "Upgrade done (KD#1452-syspref-for-anon-othernames).\n";
}
