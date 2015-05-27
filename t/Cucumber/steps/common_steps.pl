#!/usr/bin/perl

# Copyright Vaara-kirjastot 2015
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

use Modern::Perl;
use Test::More;
use Test::BDD::Cucumber::StepFile;

When qr/all scenarios are executed, tear down database changes./, sub {
    my $C = shift;
    #Forcibly make a new schema, because the existing schema might get timeout and cause this tear down step to fail.
    #Koha::Database->new_schema() just wraps around the C4::Context->dbh() which has already died :(
    #So we must get the new schema forcibly.
    my $schema = Koha::Schema->connect( sub { C4::Context->_new_dbh() }, { unsafe => 1 } );
    my $db = Koha::Database->new();
    $db->set_schema($schema);

    SImpls::BranchTransfers::deleteAllTransfers($C);
    SImpls::Issues::deleteAllIssues($C);
    SImpls::Borrowers::deleteBorrowers($C);
    SImpls::Items::deleteItems($C);
    SImpls::Accountlines::deleteAllFines($C);
    SImpls::Biblios::deleteBiblios($C);
    SImpls::MessageQueues::deleteAllMessageQueues($C);
    SImpls::LetterTemplates::deleteLetterTemplates($C);
    SImpls::SystemPreferences::rollbackSystemPreferences($C);
    SImpls::Overdues::OverdueCalendar::deleteAllOverdueCalendarRules($C);
    SImpls::Overdues::OverdueRulesMap::deleteAllOverdueRules($C);
};
