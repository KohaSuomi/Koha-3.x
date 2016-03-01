#! /usr/bin/perl

use strict;
use warnings;
use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh;
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('#636')) {
    $dbh->do("
            ALTER TABLE payments_transactions
            ADD is_self_payment int(11) NOT NULL DEFAULT 0
            ");

    $dbh->do("INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('cpuitemnumbers_online_shop', '', '', 'Maps Koha account types into Ceepos items', 'textarea')");
    $dbh->do("INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('OnlinePaymentMinTotal', '0', '', 'Defines a minimum amount of money that Borrower can pay through online payments', 'Integer')");

    print "Upgrade done (KD#636 CPU integration: Online payments\n";
}
