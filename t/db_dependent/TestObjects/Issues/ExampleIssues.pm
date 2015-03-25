package t::db_dependent::TestObjects::Issues::ExampleIssues;

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
#

use Modern::Perl;
use Carp;

use t::db_dependent::TestObjects::Issues::IssueFactory;

=head createTestGroupX

    You should use the appropriate Factory-class to create these test-objects.

=cut



sub createTestGroup1 {
    return t::db_dependent::TestObjects::Issues::IssueFactory::createTestGroup();
}
sub deleteTestGroup1 {
    t::db_dependent::TestObjects::Issues::IssueFactory::_deleteTestGroupFromIdentifiers();
}

1;