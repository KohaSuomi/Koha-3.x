package SImpls::Biblios;

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
use Carp;
use Test::More;

use t::db_dependent::TestObjects::Biblios::BiblioFactory;

sub addBiblios {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    $S->{biblios} = {} unless $S->{biblios};
    $F->{biblios} = {} unless $F->{biblios};

    my $records = t::db_dependent::TestObjects::Biblios::BiblioFactory::createTestGroup($C->data(),'biblioitems.isbn');

    while( my ($key, $record) = each %$records) {
        $S->{biblios}->{ $key } = $record;
        $F->{biblios}->{ $key } = $record;
    }
}

sub deleteBiblios {
    my $C = shift;
    my $F = $C->{stash}->{feature};
    t::db_dependent::TestObjects::Biblios::BiblioFactory::deleteTestGroup( $F->{biblios} );
}

1;
