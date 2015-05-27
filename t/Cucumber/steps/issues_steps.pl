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

use SImpls::Issues;

Given qr/there are no previous issues/, sub {
    SImpls::Issues::deleteAllIssues(@_);
};

Given qr/a set of overdue Issues, checked out from the Items' current holdingbranch/, sub {
    my $C = shift;
    SImpls::Issues::addIssues($C, 'holdingbranch');
};

Given qr/a set of Issues, checked out from the Items' current '(\w+)'/, sub {
    my $C = shift;
    SImpls::Issues::addIssues($C, $C->matches()->[0]);
};

When qr/checked-out Items are checked-in to their '(\w+)'/, sub {
    my $C = shift;
    SImpls::Issues::checkInIssues($C, $C->matches()->[0]);
};
