#! /usr/bin/perl

use strict;
use warnings;
use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh;
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('Bug16200')) {
    $dbh->do("UPDATE accountlines SET accounttype='HE', description=itemnumber WHERE (description REGEXP '^Hold waiting too long [0-9]+') AND accounttype='F';");
    print "Upgrade done (Bug 16200 - Convert expired holds to accounttype HE)\n";
}

