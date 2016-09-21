#!/usr/bin/perl

# Copyright KohaSuomi
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('KD1159-1')) {

    use C4::Members::AttributeTypes;
    my $attr_type = C4::Members::AttributeTypes->new('SST&C', 'Self-service terms and conditions accepted');
    $attr_type->opac_display(1);
    $attr_type->authorised_value_category('YES_NO');
    $attr_type->store();

    print "Upgrade done (KD-1159-1: Self-Service permission API - Added terms and conditions to be acceptable)\n";
}
