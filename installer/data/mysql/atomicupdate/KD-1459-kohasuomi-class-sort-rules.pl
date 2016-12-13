use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless ($atomicUpdater->find('KD#1459-kohasuomi-class-sort-rules')) {

    $dbh->do("INSERT INTO class_sort_rules (class_sort_rule, description, sort_routine) VALUES ('outi', 'Outi järjestelysääntö', 'OUTI');");
    $dbh->do("INSERT INTO class_sort_rules (class_sort_rule, description, sort_routine) VALUES ('lumme', 'Lumme järjestelysääntö', 'LUMME');");

    print "Upgrade done (KD#1459-kohasuomi-class-sort-rules).\n";
}
