package SImpls::LetterTemplates;

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

use t::db_dependent::TestObjects::LetterTemplates::LetterTemplateFactory;

sub addLetterTemplates {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    $S->{letterTemplates} = {} unless $S->{letterTemplates};
    $F->{letterTemplates} = {} unless $F->{letterTemplates};

    #Split the given message_transport_types-column to separate mtts
    #and create separate letterTemplates for each mtt.
    my $data = $C->data();
    my @letterTemplatesSeparatedMTTs;
    foreach my $lt (@$data) {
        my @mtts = map {my $a = $_; $a =~ s/\s+//gsm; $a;} split(',', $lt->{message_transport_types});
        delete $lt->{message_transport_types};
        foreach my $mtt (@mtts) {
            my %newLt = %$lt; #Clone the messageQueue.
            $newLt{message_transport_type} = $mtt;
            $newLt{content} =~ s/\\n/\n/gsm;
            push @letterTemplatesSeparatedMTTs, \%newLt;
        }
    }

    my $letterTemplates = t::db_dependent::TestObjects::LetterTemplates::LetterTemplateFactory::createTestGroup(\@letterTemplatesSeparatedMTTs, undef);

    while( my ($key, $letterTemplate) = each %$letterTemplates) {
        $S->{letterTemplates}->{ $key } = $letterTemplate;
        $F->{letterTemplates}->{ $key } = $letterTemplate;
    }
}

sub deleteLetterTemplates {
    my $C = shift;
    my $F = $C->{stash}->{feature};
    t::db_dependent::TestObjects::LetterTemplates::LetterTemplateFactory::deleteTestGroup( $F->{letterTemplates} );
}

sub deleteAllLetterTemplates {
    my $schema = Koha::Database->new()->schema();
    $schema->resultset('Letter')->search({})->delete_all();
}

1;
