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

use Koha::Database;
use Koha::Overdues::OverdueRulesMap;

use SImpls::Overdues::OverdueRulesMap;


Given qr/a set of overduerules/, sub {
    SImpls::Overdues::OverdueRulesMap::addOverdueRules(@_);
};

Given qr/there are no previous overduerules/, sub {
    SImpls::Overdues::OverdueRulesMap::deleteAllOverdueRules( @_ );
};

When qr/I've updated the following overduerules/, sub {
    SImpls::Overdues::OverdueRulesMap::addOverdueRules( @_ );
};

When qr/I try to add overduerules with bad values, I get errors./, sub {
    SImpls::Overdues::OverdueRulesMap::When_I_try_to_add_overduerules_with_bad_values_I_get_errors(  @_  );
};

When qr/I've deleted the following overduerules, then I cannot find them./, sub {
    SImpls::Overdues::OverdueRulesMap::When_I_ve_deleted_overduerules_then_cannot_find_them(  @_  );
};

When qr/I request the last overdue rules in '(scalar|list)'-context/, sub {
    SImpls::Overdues::OverdueRulesMap::getLastOverdueRules( shift, $1 );
};

Then qr/I should find the rules from the OverdueRulesMap-object./, sub {
    SImpls::Overdues::OverdueRulesMap::Find_the_overduerules_from_overdueRulesMap( @_ );
};

Then qr/I get the following last overduerules/, sub {
    SImpls::Overdues::OverdueRulesMap::Then_get_following_last_overduerules( @_ );
};

Then qr/I cannot find any overduerules/, sub {
    my $schema = Koha::Database->new()->schema();
    my @overduerules = $schema->resultset('Overduerule')->search({})->all;
    is((scalar(@overduerules)), 0, "Cleaning overduerules succeeded");
    my @overduerulesTransportTypes = $schema->resultset('OverduerulesTransportType')->search({})->all;
    is((scalar(@overduerulesTransportTypes)), 0, "Cleaning overduerule_transport_types succeeded");
};
