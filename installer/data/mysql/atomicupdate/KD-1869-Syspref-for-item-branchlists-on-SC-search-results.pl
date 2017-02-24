use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless ($atomicUpdater->find('KD#1869-Syspref-for-item-branchlists-on-SC-search-results')) {

    $dbh->do(
        "INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('ShowBranchListOnSearchResults', '1', null, 'Show a list branches with availability information on search results', 'YesNo');"
    );

    print "Upgrade done (KD#1869-Syspref-for-item-branchlists-on-SC-search-results).\n";
}
