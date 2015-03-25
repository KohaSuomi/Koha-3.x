package t::db_dependent::TestObjects::Biblios::BiblioFactory;

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

use C4::Biblio;

use t::db_dependent::TestObjects::Biblios::ExampleBiblios;
use t::db_dependent::TestObjects::ObjectFactory;

=head t::db_dependent::TestObjects::Biblios::createTestGroup( $data [, $hashKey] )
Calls C4::Biblio::TransformKohaToMarc() to make a MARC::Record and add it to
the DB. Returns a HASH of MARC::Records.
The HASH is keyed with the biblionumber, or the given $hashKey.
The biblionumber is injected to the MARC::Record-object to be easily accessable,
so we can get it like this:
    $records->{$key}->{biblionumber};

See C4::Biblio::TransformKohaToMarc() for how the biblio- or biblioitem-tables'
columns need to be given.
=cut

sub createTestGroup {
    my ($biblios, $hashKey) = @_;
    my %records;
    foreach my $biblio (@$biblios) {
        my $record = C4::Biblio::TransformKohaToMarc($biblio);
        my ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($record,'');
        $record->{biblionumber} = $biblionumber;

        my $key = t::db_dependent::TestObjects::ObjectFactory::getHashKey($biblio, $biblionumber, $hashKey);

        $records{$key} = $record;
    }
    return \%records;
}

=head

    my $records = createTestGroup();
    ##Do funky stuff
    deleteTestGroup($records);

Removes the given test group from the DB.

=cut

sub deleteTestGroup {
    my $records = shift;

    my ( $biblionumberFieldCode, $biblionumberSubfieldCode ) =
            C4::Biblio::GetMarcFromKohaField( "biblio.biblionumber", '' );

    my $schema = Koha::Database->new_schema();
    while( my ($key, $record) = each %$records) {
        my $biblionumber = $record->subfield($biblionumberFieldCode, $biblionumberSubfieldCode);
        $schema->resultset('Biblio')->search($biblionumber)->delete_all();
        $schema->resultset('Biblioitem')->search($biblionumber)->delete_all();
    }
}
sub _deleteTestGroupFromIdentifiers {
    my $testGroupIdentifiers = shift;

    my $schema = Koha::Database->new_schema();
    foreach my $isbn (@$testGroupIdentifiers) {
        $schema->resultset('Biblio')->search({"biblioitems.isbn" => $isbn},{join => 'biblioitems'})->delete();
        $schema->resultset('Biblioitem')->search({isbn => $isbn})->delete();
    }
}

sub createTestGroup1 {
    return t::db_dependent::TestObjects::Biblios::ExampleBiblios::createTestGroup1();
}
sub deleteTestGroup1 {
    return t::db_dependent::TestObjects::Biblios::ExampleBiblios::deleteTestGroup1();
}

1;