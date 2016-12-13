#! /usr/bin/perl

use strict;
use warnings;
use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh;
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('#1036')) {
    $dbh->do("
            ALTER TABLE payments_transactions
            ADD user_branch varchar(10)
            ");

    print "Upgrade done (KD#1036 Add user branch column to payments_transactions)\n";
}
