#!/usr/bin/perl

# Copyright 2009 BibLibre
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use CGI;
use Encode qw(decode encode);
use Carp;

use Mail::Sendmail;
use MIME::QuotedPrint;
use MIME::Base64;
use C4::Auth;
use C4::Biblio;
use C4::Items;
use C4::Output;
use C4::VirtualShelves;

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user (
    {
        template_name   => "virtualshelves/sendshelfform.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1 },
    }
);

my $shelfid = $query->param('shelfid');
my $email   = $query->param('email');

my $dbh          = C4::Context->dbh;

if ( $email ) {
    my $email_from = C4::Context->preference('KohaAdminEmailAddress');
    my $comment    = $query->param('comment');

    my %mail = (
        To   => $email,
        From => $email_from
    );

    my ( $template2, $borrowernumber, $cookie ) = get_template_and_user(
        {
	    template_name   => "virtualshelves/sendshelf.tmpl",
	    query           => $query,
	    type            => "intranet",
	    authnotrequired => 0,
	    flagsrequired   => { catalogue => 1 },
        }
    );

    my @shelf               = GetShelf($shelfid);
    my ($items, $totitems)  = GetShelfContents($shelfid);
    my $marcflavour         = C4::Context->preference('marcflavour');
    my $iso2709;
    my @results;

    # retrieve biblios from shelf
    foreach my $biblio (@$items) {
        my $biblionumber     = $biblio->{biblionumber};
        my $fw               = GetFrameworkCode($biblionumber);
        my $dat              = GetBiblioData($biblionumber);
        my $record           = GetMarcBiblio($biblionumber);
        my $marcnotesarray   = GetMarcNotes( $record, $marcflavour );
        my $marcauthorsarray = GetMarcAuthors( $record, $marcflavour );
        my $marcsubjctsarray = GetMarcSubjects( $record, $marcflavour );
        my $subtitle         = GetRecordValue('subtitle', $record, $fw);

        my @items = GetItemsInfo( $biblionumber );

        $dat->{MARCNOTES}      = $marcnotesarray;
        $dat->{MARCSUBJCTS}    = $marcsubjctsarray;
        $dat->{MARCAUTHORS}    = $marcauthorsarray;
        $dat->{'biblionumber'} = $biblionumber;
        $dat->{ITEM_RESULTS}   = \@items;
        $dat->{subtitle}       = $subtitle;

        $iso2709 .= $record->as_usmarc();

        push( @results, $dat );
    }

  if (C4::Context->preference('OPACBaseURL')){
        $template2->param( OPACBaseURL => C4::Context->preference('OPACBaseURL') );
  }

    $template2->param(
        BIBLIO_RESULTS => \@results,
        email_sender   => $email_from,
        comment        => $comment,
        shelfname      => $shelf[1],
    );

    # Getting template result
    my $template_res = $template2->output();
    my $template_res_over = $template_res;
    my $body;

    # Analysing information and getting mail properties
    if ( $template_res =~ /<SUBJECT>(.*)<END_SUBJECT>/s ) {
        $mail{subject} = $1;
        $mail{subject} =~ s|\n?(.*)\n?|$1|;
    }
    else { $mail{'subject'} = "no subject"; }

    my $email_header = "";
    if ( $template_res =~ /<HEADER>(.*)<END_HEADER>/s ) {
        $email_header = $1;
        $email_header =~ s|\n?(.*)\n?|$1|;
        $email_header = encode_qp($email_header);
    }

    my $email_file = "list.txt";
    if ( $template_res =~ /<FILENAME>(.*)<END_FILENAME>/s ) {
        $email_file = $1;
        $email_file =~ s|\n?(.*)\n?|$1|;
    }

    if ( $template_res =~ /<MESSAGE>(.*)<END_MESSAGE>/s ) {
        $body = $1;
        $body =~ s|\n?(.*)\n?|$1|;
        $body = encode_qp($body);
    }

    my $boundary = "====" . time() . "====";

    # We set and put the multipart content
    $mail{'content-type'} = "multipart/mixed; boundary=\"$boundary\"";

    my $isofile = encode_base64(encode("UTF-8", $iso2709));
    $boundary = '--' . $boundary;

    $mail{body} = <<END_OF_BODY;
$boundary
Content-Type: text/plain; charset="utf-8"
Content-Transfer-Encoding: quoted-printable

$email_header
$body
$boundary
Content-Type: application/octet-stream; name="shelf.iso2709"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="shelf.iso2709"

$isofile
$boundary--
END_OF_BODY

#use Data::Dumper;
#open(FH, ">", "/tmp/lol");
#print FH Data::Dumper::Dumper(\%mail);
#close(FH);

    my $dbh       = C4::Context->dbh();
    my $statement = << 'ENDSQL';
INSERT INTO message_queue
( borrowernumber, subject, content, metadata, letter_code, message_transport_type, status, time_queued, to_address, from_address, content_type )
VALUES
( ?,              ?,       ?,       ?,        ?,           ?,                      ?,      NOW(),       ?,          ?,            ? )
ENDSQL

    my $sth    = $dbh->prepare($statement);
    my $result = $sth->execute(
$borrowernumber, decode('UTF-8',$mail{subject}), decode('UTF-8',$template_res_over), '', 'VIRTUALSH','email','pending', $email, $email_from, ''
);

#    # Sending mail
#    if ( sendmail %mail ) {
#        # do something if it works....
        $template->param( SENT      => "1" );
#    }
#    else {
#        # do something if it doesnt work....
#        carp "Error sending mail: $Mail::Sendmail::error \n";
#        $template->param( error => 1 );
#    }
#
    $template->param( email => $email );
    output_html_with_http_headers $query, $cookie, $template->output;


}else{
    $template->param( shelfid => $shelfid,
                      url     => "/cgi-bin/koha/virtualshelves/sendshelf.pl",
                    );
    output_html_with_http_headers $query, $cookie, $template->output;
}
