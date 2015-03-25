package t::db_dependent::TestObjects::LetterTemplates::ExampleLetterTemplates;

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

use t::db_dependent::TestObjects::LetterTemplates::LetterTemplateFactory;

=head createTestGroupX

    You should use the appropriate Factory-class to create these test-objects.

=cut

my @testGroup1Identifiers = ('circulation-ODUE1-CPL-print', 'circulation-ODUE2-CPL-print', 'circulation-ODUE3-CPL-print',
                             'circulation-ODUE1-CPL-email', 'circulation-ODUE2-CPL-email', 'circulation-ODUE3-CPL-email',
                             'circulation-ODUE1-CPL-sms', 'circulation-ODUE2-CPL-sms', 'circulation-ODUE3-CPL-sms',
                            );

sub createTestGroup1 {
    my @letterTemplates = (
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE1', branchcode => 'CPL', name => 'Notice1',
         is_html => undef, title => 'Notice1', message_transport_type => 'print',
         content => '<item>Barcode: <<items.barcode>>, bring it back!</item>',
        },
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE2', branchcode => 'CPL', name => 'Notice2',
         is_html => undef, title => 'Notice2', message_transport_type => 'print',
         content => '<item>Barcode: <<items.barcode>></item>',
        },
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE3', branchcode => 'CPL', name => 'Notice3',
         is_html => undef, title => 'Notice3', message_transport_type => 'print',
         content => '<item>Barcode: <<items.barcode>>, bring back!</item>',
        },
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE1', branchcode => 'CPL', name => 'Notice1',
         is_html => undef, title => 'Notice1', message_transport_type => 'email',
         content => '<item>Barcode: <<items.barcode>>, bring it back!</item>',
        },
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE2', branchcode => 'CPL', name => 'Notice2',
         is_html => undef, title => 'Notice2', message_transport_type => 'email',
         content => '<item>Barcode: <<items.barcode>></item>',
        },
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE3', branchcode => 'CPL', name => 'Notice3',
         is_html => undef, title => 'Notice3', message_transport_type => 'email',
         content => '<item>Barcode: <<items.barcode>>, bring back!</item>',
        },
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE1', branchcode => 'CPL', name => 'Notice1',
         is_html => undef, title => 'Notice1', message_transport_type => 'sms',
         content => '<item>Barcode: <<items.barcode>>, bring it back!</item>',
        },
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE2', branchcode => 'CPL', name => 'Notice2',
         is_html => undef, title => 'Notice2', message_transport_type => 'sms',
         content => '<item>Barcode: <<items.barcode>></item>',
        },
        {letter_id => $testGroup1Identifiers[0],
         module => 'circulation', code => 'ODUE3', branchcode => 'CPL', name => 'Notice3',
         is_html => undef, title => 'Notice3', message_transport_type => 'sms',
         content => '<item>Barcode: <<items.barcode>>, bring back!</item>',
        },
    );

    return t::db_dependent::TestObjects::LetterTemplates::LetterTemplateFactory::createTestGroup(\@letterTemplates);
}
sub deleteTestGroup1 {
    t::db_dependent::TestObjects::LetterTemplates::LetterTemplateFactory::_deleteTestGroupFromIdentifiers(\@testGroup1Identifiers);
}

1;