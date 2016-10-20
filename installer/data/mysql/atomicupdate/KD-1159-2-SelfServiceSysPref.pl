#!/usr/bin/perl

# Copyright KohaSuomi
#
# This file is part of Koha.
#

use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('KD1159-2')) {

    $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('SSRules','0:ST S PT',NULL,\"Self-service access rules, age limit + whitelisted borrower categories, eg. '15:ST S PT'\",'text')");

    use C4::Members::AttributeTypes;
    my $attr_type = C4::Members::AttributeTypes->new('SSBAN', 'Self-service usage revoked');
    $attr_type->opac_display(1);
    $attr_type->authorised_value_category('YES_NO');
    $attr_type->store();

    print "Upgrade done (KD-1159-2: Self-Service permission API - Added syspref SSRules to configure the REST API endpoint /borrowers/sstatus and added borrower attribute SSBAN to block self-service usage)\n";
}
