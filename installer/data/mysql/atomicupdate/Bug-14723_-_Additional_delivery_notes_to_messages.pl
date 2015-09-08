#! /usr/bin/perl

use strict;
use warnings;
use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh;
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('Bug14723')) {
    $dbh->do("ALTER TABLE message_queue ADD delivery_note TEXT");
    print "Upgrade to done (Bug 14723 - Additional delivery notes to messages)\n";
}
