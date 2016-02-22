package Koha::REST::V1::Records;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';

use MARC::Record;
use Encode;

use Koha::REST::V1;
use Koha::REST::V1::Biblios;
use C4::Biblio;


sub add_record {
    my ($c, $args, $cb) = @_;
    my ($record, $newXmlRecord, $biblionumber, $biblioitemnumber);

    ##Test that encoding is valid utf8
    eval { Encode::decode_utf8($args->{marcxml}, Encode::FB_CROAK); };
    if ($@) {
        return $c->$cb({error => "Given marcxml is not valid utf8:\n".$args->{marcxml}."\nError: '$@'"}, 400);
    }

    ##Can we parse XML to MARC::Record?
    eval { $record = MARC::Record->new_from_xml( $args->{marcxml}, 'utf8', C4::Context->preference("marcflavour") ); };
    if ($@) {
        return $c->$cb({error => "Couldn't parse the given marcxml:\n".$args->{marcxml}."\nError: '$@'"}, 400);
    }

    ##Validate that the MARC::Record has 001 and 003. Super important for cross database record sharing!!
    my @mandatoryFields = ('001', '003');
    my @fieldValues;
    eval { push(@fieldValues, $record->field($_)->data()) if $record->field($_)->data() } for @mandatoryFields;
    if ($@ || not (@mandatoryFields == @fieldValues)) {
        return $c->$cb({error => "One of mandatory fields '@mandatoryFields' missing, field values '@fieldValues'. For the given marcxml :\n".$args->{marcxml}}, 400);
    }

    ##Make a duplication check
    my @matches = C4::Matcher->fetch(1)->get_matches($record, 2);
    if (@matches) {
        return $c->$cb({error => "Couldn't add the MARC Record to the database:\nThe given record duplicates an existing record \"".$matches[0]->{'record_id'}."\". Using matcher 1.\n\nMARC XML of this record:\n".$args->{marcxml}}, 400);
    }

    ##Can we write to DB?
    eval { ($biblionumber, $biblioitemnumber) = C4::Biblio::AddBiblio($record, ''); }; #Add to the default framework code
    if ($@ || not($biblionumber)) {
        return $c->$cb({error => "Couldn't add the given marcxml to the database:\n".$args->{marcxml}."\nError: '$@'"}, 500);
    }

    ##Can we get the Koha's mangled version of input data back?
    eval { $newXmlRecord = C4::Biblio::GetXmlBiblio($biblionumber); };
    if ($@ || not($newXmlRecord)) {
        return $c->$cb({error => "Couldn't get the given marcxml back from the database??:\n".$args->{marcxml}."\nError: '$@'"}, 500);
    }

    my $responseBody = {biblionumber => 0+$biblionumber, marcxml => $newXmlRecord};
    ##Attach HATEOAS links to response
    Koha::REST::V1::hateoas($c, $responseBody, 'self.nativeView', "/cgi-bin/koha/catalogue/detail.pl?biblionumber=$biblionumber");

    ##Phew, we survived.
    return $c->$cb($responseBody, 200);
}

sub get_record {
    my ($c, $args, $cb) = @_;
    my ($xmlRecord);

    ##Can we get the XML?
    eval { $xmlRecord = C4::Biblio::GetXmlBiblio($args->{biblionumber}); };
    if ($@) {
        return $c->$cb({error => "Couldn't get the given marcxml from the database??:\n".$args->{biblionumber}."\nError: '$@'"}, 500);
    }
    if (not($xmlRecord)) {
        return $c->$cb({error => "No such MARC record in our database for biblionumber '".$args->{biblionumber}."'"}, 404);
    }

    ##Phew, we survived.
    return $c->$cb({biblionumber => 0+$args->{biblionumber}, marcxml => $xmlRecord}, 200);
}

sub delete_record {
    return Koha::REST::V1::Biblios::delete_biblio(@_);
}

1;
