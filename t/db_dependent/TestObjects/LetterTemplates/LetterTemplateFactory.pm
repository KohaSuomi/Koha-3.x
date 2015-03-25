package t::db_dependent::TestObjects::LetterTemplates::LetterTemplateFactory;

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

use C4::Letters;

use t::db_dependent::TestObjects::LetterTemplates::ExampleLetterTemplates;
use t::db_dependent::TestObjects::ObjectFactory qw(getHashKey);

=head t::db_dependent::TestObjects::LetterTemplates::LetterTemplateFactory::createTestGroup( $data [, $hashKey] )
Returns a HASH of Koha::Schema::Result::Letter
The HASH is keyed with the PRIMARY KEYS eg. 'circulation-ODUE2-CPL-print', or the given $hashKey.
=cut

#Incredibly the Letters-module has absolutely no Create or Update-component to operate on Letter templates?
#Tests like these are brittttle. :(
sub createTestGroup {
    my ($objects, $hashKey) = @_;

    my %objects;
    my $schema = Koha::Database->new()->schema();
    foreach my $object (@$objects) {
        my $rs = $schema->resultset('Letter');
        my $result = $rs->update_or_create({
                module     => $object->{module},
                code       => $object->{code},
                branchcode => ($object->{branchcode}) ? $object->{branchcode} : '',
                name       => $object->{name},
                is_html    => $object->{is_html},
                title      => $object->{title},
                message_transport_type => $object->{message_transport_type},
                content    => $object->{content},
        });

        my @pks = $result->id();
        my $key = t::db_dependent::TestObjects::ObjectFactory::getHashKey($object, join('-',@pks), $hashKey);

        $objects{$key} = $result;
    }
    return \%objects;
}

=head

    my $objects = createTestGroup();
    ##Do funky stuff
    deleteTestGroup($records);

Removes the given test group from the DB.

=cut

sub deleteTestGroup {
    my $objects = shift;

    my $schema = Koha::Database->new_schema();
    while( my ($key, $object) = each %$objects) {
        $object->delete();
    }
}
sub _deleteTestGroupFromIdentifiers {
    my $testGroupIdentifiers = shift;

    my $schema = Koha::Database->new_schema();
    foreach my $key (@$testGroupIdentifiers) {
        my ($module, $code, $branchcode, $mtt) = split('-',$key);
        $schema->resultset('Letter')->find({module => $module,
                                                    code => $code,
                                                    branchcode => $branchcode,
                                                    message_transport_type => $mtt,
                                                })->delete();
    }
}

sub createTestGroup1 {
    return t::db_dependent::TestObjects::LetterTemplates::ExampleLetterTemplates::createTestGroup1();
}
sub deleteTestGroup1 {
    return t::db_dependent::TestObjects::LetterTemplates::ExampleLetterTemplates::deleteTestGroup1();
}

1;