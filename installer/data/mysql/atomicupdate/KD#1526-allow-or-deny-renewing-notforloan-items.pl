use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless ($atomicUpdater->find('KD#1526-allow-or-deny-renewing-notforloan-items')) {

    $dbh->do(
        "INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('AllowRenewingNotforloanItems', '1', null, 'If set, renewing items with notforloan status is allowed', 'YesNo');"
    );

    print "Upgrade done (KD#1526-allow-or-deny-renewing-notforloan-items).\n";
}
