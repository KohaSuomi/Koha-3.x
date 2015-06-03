#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 3;
use Test::MockModule;

use MARC::Record;
use t::lib::Mocks qw( mock_preference );

BEGIN {
    use_ok('C4::Biblio');
}

my $dbh = C4::Context->dbh;
# Start transaction
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

# Mocking variables
my $context             = new Test::MockModule('C4::Context');

mock_marcfromkohafield();

sub run_tests {

    # Undef C4::Biblio::inverted_field_map to avoid problems introduced
    # by caching in TransformMarcToKoha
    undef $C4::Biblio::inverted_field_map;

    my $marcflavour = shift;
    t::lib::Mocks::mock_preference('marcflavour', $marcflavour);

    my $isbn = '0590353403';
    my $title = 'Foundation';

    # Generate a record with just the ISBN
    my $marc_record = MARC::Record->new;
    my $isbn_field  = create_isbn_field( $isbn, $marcflavour );
    $marc_record->append_fields( $isbn_field );

    # Add the record to the DB
    my( $biblionumber, $biblioitemnumber ) = AddBiblio( $marc_record, '' );
    my $data = GetBiblioData( $biblionumber );
    is( $data->{ isbn }, $isbn,
        '(GetBiblioData) ISBN correctly retireved.');
    is( $data->{ title }, undef,
        '(GetBiblioData) Title field is empty in fresh biblio.');

    # Add title
    my $field = create_title_field( $title, $marcflavour );
    $marc_record->append_fields( $field );
    ModBiblio( $marc_record, $biblionumber ,'' );
    $data = GetBiblioData( $biblionumber );
    is( $data->{ title }, $title,
        'ModBiblio correctly added the title field, and GetBiblioData.');
    is( $data->{ isbn }, $isbn, '(ModBiblio) ISBN is still there after ModBiblio.');

    my $itemdata = GetBiblioItemData( $biblioitemnumber );
    is( $itemdata->{ title }, $title,
        'First test of GetBiblioItemData to get same result of previous two GetBiblioData tests.');
    is( $itemdata->{ isbn }, $isbn,
        'Second test checking it returns the correct isbn.');

    my $success = 0;
    $field = MARC::Field->new(
            655, ' ', ' ',
            'a' => 'Auction catalogs',
            '9' => '1'
            );
    eval {
        $marc_record->append_fields($field);
        $success = ModBiblio($marc_record,$biblionumber,'');
    } or do {
        diag($@);
        $success = 0;
    };
    ok($success, "ModBiblio handles authority-linked 655");

    eval {
        $field->delete_subfields('a');
        $marc_record->append_fields($field);
        $success = ModBiblio($marc_record,$biblionumber,'');
    } or do {
        diag($@);
        $success = 0;
    };
    ok($success, "ModBiblio handles 655 with authority link but no heading");

    eval {
        $field->delete_subfields('9');
        $marc_record->append_fields($field);
        $success = ModBiblio($marc_record,$biblionumber,'');
    } or do {
        diag($@);
        $success = 0;
    };
    ok($success, "ModBiblio handles 655 with no subfields");

    ## Testing GetMarcISSN
    my $issns;
    $issns = GetMarcISSN( $marc_record, $marcflavour );
    is( $issns->[0], undef,
        'GetMarcISSN handles records without the ISSN field (list is empty)' );
    is( scalar @$issns, 0,
        'GetMarcISSN handles records without the ISSN field (count is 0)' );
    # Add an ISSN field
    my $issn = '1234-1234';
    $field = create_issn_field( $issn, $marcflavour );
    $marc_record->append_fields($field);
    $issns = GetMarcISSN( $marc_record, $marcflavour );
    is( $issns->[0], $issn,
        'GetMarcISSN handles records with a single ISSN field (first element is correct)' );
    is( scalar @$issns, 1,
        'GetMARCISSN handles records with a single ISSN field (count is 1)');
    # Add multiple ISSN field
    my @more_issns = qw/1111-1111 2222-2222 3333-3333/;
    foreach (@more_issns) {
        $field = create_issn_field( $_, $marcflavour );
        $marc_record->append_fields($field);
    }
    $issns = GetMarcISSN( $marc_record, $marcflavour );
    is( scalar @$issns, 4,
        'GetMARCISSN handles records with multiple ISSN fields (count correct)');

    testGetBiblionumberSlice($marcflavour);

    ## Testing GetMarcControlnumber
    my $controlnumber;
    $controlnumber = GetMarcControlnumber( $marc_record, $marcflavour );
    is( $controlnumber, '', 'GetMarcControlnumber handles records without 001' );

    $field = MARC::Field->new( '001', '' );
    $marc_record->append_fields($field);
    $controlnumber = GetMarcControlnumber( $marc_record, $marcflavour );
    is( $controlnumber, '', 'GetMarcControlnumber handles records with empty 001' );

    $field = $marc_record->field('001');
    $field->update('123456789X');
    $controlnumber = GetMarcControlnumber( $marc_record, $marcflavour );
    is( $controlnumber, '123456789X', 'GetMarcControlnumber handles records with 001' );

    ## Testing GetMarcISBN
    my $record_for_isbn = MARC::Record->new();
    my $isbns = GetMarcISBN( $record_for_isbn, $marcflavour );
    is( scalar @$isbns, 0, '(GetMarcISBN) The record contains no ISBN');

    # We add one ISBN
    $isbn_field = create_isbn_field( $isbn, $marcflavour );
    $record_for_isbn->append_fields( $isbn_field );
    $isbns = GetMarcISBN( $record_for_isbn, $marcflavour );
    is( scalar @$isbns, 1, '(GetMarcISBN) The record contains one ISBN');
    is( $isbns->[0], $isbn, '(GetMarcISBN) The record contains our ISBN');

    # We add 3 more ISBNs
    $record_for_isbn = MARC::Record->new();
    my @more_isbns = qw/1111111111 2222222222 3333333333 444444444/;
    foreach (@more_isbns) {
        $field = create_isbn_field( $_, $marcflavour );
        $record_for_isbn->append_fields($field);
    }
    $isbns = GetMarcISBN( $record_for_isbn, $marcflavour );
    is( scalar @$isbns, 4, '(GetMarcISBN) The record contains 4 ISBNs');
    for my $i (0 .. $#more_isbns) {
        is( $isbns->[$i], $more_isbns[$i],
            "(GetMarcISBN) Corretly retrieves ISBN #". ($i + 1));
    }

}

sub mock_marcfromkohafield {

    $context->mock('marcfromkohafield',
        sub {
            my ( $self ) = shift;

            if ( C4::Context->preference('marcflavour') eq 'MARC21' ) {

                return  {
                '' => {
                    'biblio.title' => [ '245', 'a' ],
                    'biblio.biblionumber' => [ '999', 'c' ],
                    'biblioitems.isbn' => [ '020', 'a' ],
                    'biblioitems.issn' => [ '022', 'a' ],
                    'biblioitems.biblioitemnumber' => [ '999', 'd' ]
                    }
                };
            } elsif ( C4::Context->preference('marcflavour') eq 'UNIMARC' ) {

                return {
                '' => {
                    'biblio.title' => [ '200', 'a' ],
                    'biblio.biblionumber' => [ '999', 'c' ],
                    'biblioitems.isbn' => [ '010', 'a' ],
                    'biblioitems.issn' => [ '011', 'a' ],
                    'biblioitems.biblioitemnumber' => [ '090', 'a' ]
                    }
                };
            }
        });
}

sub addMockBiblio {
    my $isbn = shift;
    my $marcflavour = shift;

    # Generate a record with just the ISBN
    my $marc_record = MARC::Record->new;
    my $isbn_field  = create_isbn_field( $isbn, $marcflavour );
    $marc_record->append_fields( $isbn_field );

    # Add the record to the DB
    my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $marc_record, '' );
    return ( $biblionumber, $biblioitemnumber );
}

sub create_title_field {
    my ( $title, $marcflavour ) = @_;

    my $title_field = ( $marcflavour eq 'UNIMARC' ) ? '200' : '245';
    my $field = MARC::Field->new( $title_field,'','','a' => $title);

    return $field;
}

sub create_isbn_field {
    my ( $isbn, $marcflavour ) = @_;

    my $isbn_field = ( $marcflavour eq 'UNIMARC' ) ? '010' : '020';
    my $field = MARC::Field->new( $isbn_field,'','','a' => $isbn);

    return $field;
}

sub create_issn_field {
    my ( $issn, $marcflavour ) = @_;

    my $issn_field = ( $marcflavour eq 'UNIMARC' ) ? '011' : '022';
    my $field = MARC::Field->new( $issn_field,'','','a' => $issn);

    return $field;
}

subtest 'MARC21' => sub {
    plan tests => 25;
    run_tests('MARC21');
    $dbh->rollback;
};

subtest 'UNIMARC' => sub {
    plan tests => 25;
    run_tests('UNIMARC');
    $dbh->rollback;
};

##Testing C4::Biblio::GetBiblionumberSlice(), runs 6 tests
sub testGetBiblionumberSlice() {
    my $marcflavour = shift;

    #Get all biblionumbers.
    my $biblionumbers = C4::Biblio::GetBiblionumberSlice(999999999999);
    my $initialCount = scalar(@$biblionumbers);
    is( ($initialCount > 0), 1, 'C4::Biblio::GetBiblionumberSlice(), Get all biblionumbers.');

    #Add a bunch of mock biblios.
    my ($bn1) = addMockBiblio('0120344506', $marcflavour);
    my ($bn2) = addMockBiblio('0230455607', $marcflavour);
    my ($bn3) = addMockBiblio('0340566708', $marcflavour);
    my ($bn4) = addMockBiblio('0450677809', $marcflavour);
    my ($bn5) = addMockBiblio('0560788900', $marcflavour);

    #Get all biblionumbers again, but now we should have 5 more.
    $biblionumbers = C4::Biblio::GetBiblionumberSlice(999999999999);
    is( $initialCount+5, scalar(@$biblionumbers), 'C4::Biblio::GetBiblionumberSlice(), Get all biblionumbers after appending 5 biblios more.');

    #Get 3 biblionumbers.
    $biblionumbers = C4::Biblio::GetBiblionumberSlice(3);
    is( 3, scalar(@$biblionumbers), 'C4::Biblio::GetBiblionumberSlice(), Get 3 biblionumbers.');

    #Get 3 biblionumbers, all of whom must be of the recently added.
    $biblionumbers = C4::Biblio::GetBiblionumberSlice(3, $initialCount);
    my $testOK = 1;
    foreach (@$biblionumbers) {
        if ($_ == $bn1 || $_ == $bn2 || $_ == $bn3) {
            #The result is part of us!
        }
        else {
            $testOK = 0; #Fail the test because we got some biblionumbers we were not meant to get.
        }
    }
    is( $testOK, 1, 'C4::Biblio::GetBiblionumberSlice(), Get 3 specific biblionumbers.');

    #Get 3 biblionumbers, all of whom must be $bn3 or added right after it.
    $biblionumbers = C4::Biblio::GetBiblionumberSlice(3, undef, $bn3);
    $testOK = 1;
    foreach (@$biblionumbers) {
        if ($_ == $bn3 || $_ == $bn4 || $_ == $bn5) {
            #The result is part of us!
        }
        else {
            $testOK = 0; #Fail the test because we got some biblionumbers we were not meant to get.
        }
    }
    is( $testOK, 1, 'C4::Biblio::GetBiblionumberSlice(), Get 3 specific biblionumbers after a specific biblionumber.');

    #Same test as the previous one, but test for offset-parameter overriding by the biblionumber-parameter.
    $biblionumbers = C4::Biblio::GetBiblionumberSlice(3, $initialCount, $bn3);
    $testOK = 1;
    foreach (@$biblionumbers) {
        if ($_ == $bn3 || $_ == $bn4 || $_ == $bn5) {
            #The result is part of us!
        }
        else {
            #Fail the test because we got some biblionumbers we were not meant to get.
            #These biblionumbers are probably $bn1 and $bn2.
            $testOK = 0;
        }
    }
    is( $testOK, 1, 'C4::Biblio::GetBiblionumberSlice(), offset-parameter overriding.');
}
1;
