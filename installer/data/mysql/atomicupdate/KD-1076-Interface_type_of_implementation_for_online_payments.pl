#! /usr/bin/perl

use strict;
use warnings;
use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh;
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('#1076')) {
    $dbh->do("DELETE FROM systempreferences WHERE variable='POSIntegration'");
    $dbh->do("DELETE FROM systempreferences WHERE variable='cpuitemnumbers_online_shop'");
    $dbh->do("DELETE FROM systempreferences WHERE variable='cpuitemnumbers'");
    $dbh->do("INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('OnlinePayments', '', '', 'Maps Koha account types into online payment store item numbers and defines the interfaces that will be used for each branch', 'textarea')");
    $dbh->do("INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('POSIntegration', '', '', 'Maps Koha account types into POS item numbers and defines the interfaces that will be used for each branch', 'textarea')");

    print "Upgrade done (KD#1076: Online payments & POS integration)\n";
}
