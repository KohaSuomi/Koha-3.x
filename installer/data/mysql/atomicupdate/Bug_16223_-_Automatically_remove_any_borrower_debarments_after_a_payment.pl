#! /usr/bin/perl

use strict;
use warnings;
use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh;
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('Bug16223')) {
    # Add system preference
    $dbh->do("INSERT INTO systempreferences (variable, value, options, explanation, type)
             VALUES ('DebarmentsToLiftAfterPayment', '', '', 'Lift these debarments after Borrower has paid his/her fees', 'textarea')");

    print "Upgrade done (Bug 16623: Automatically remove any borrower debarments after a payment)\n";
}
