package C4::OPLIB::SendAcquisitionByXML;

# Copyright 2000-2002 Katipo Communications
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
use Carp;
use C4::Context;
use C4::Debug;
use C4::Dates qw(format_date format_date_in_iso);
use MARC::Record;
use C4::Branch;
use C4::Biblio;
use C4::SQLHelper qw(InsertInTable UpdateInTable);
use C4::Bookseller qw(GetBookSellerFromId);
use C4::Templates qw(gettemplate);
use C4::Acquisition qw/GetOrders GetBasketsByBasketgroup GetBasketgroup GetBasket ModBasketgroup GetContract/;
use XML::Simple;
use XML::Writer;
use IO::File;
use Data::Dumper;

use Time::localtime;
use Time::Local;
use HTML::Entities;

use Encode;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

BEGIN {
    # set the version for version checking
    $VERSION = 3.07.00.049;
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        getField
        getSubfield
    );
}

=head3 sendBasketGroupAsXml

=over

&sendBasketGroupAsXml;

Export a basket group as XML

$cgi parameter is needed for column name translation

=back

=cut

sub sendBasketGroupAsXml{
    my $basketgroupid = shift;
    my $filename = 'tilaus' . $basketgroupid . '.xml';
    my $baskets = GetBasketsByBasketgroup($basketgroupid);
    my $basketgroup = GetBasketgroup( $basketgroupid );
    my $bookseller = GetBookSellerFromId( $basketgroup->{booksellerid} );

    my $output = new IO::File(">/tmp/".$filename);
    my $writer = new XML::Writer(OUTPUT => $output);

    my $branchname = encode('utf8', GetBranchName($basketgroup->{billingplace}));

    $writer->xmlDecl( 'UTF-8' );

    $writer->startTag('customer', 'name' => $branchname, 'nr' => $bookseller->{accountnumber});    

    #Stuff starts here
    for my $basket (@$baskets) {
        my @orders     = GetOrders( $$basket{basketno} );
        my $contract   = GetContract( $$basket{contractnumber} );
        
        foreach my $order (@orders) {
            my $bd = GetBiblioData( $order->{'biblionumber'} );
            my $marcxml = $bd->{marcxml};
            my $allfons = getField($marcxml, '001');
            my $field971 = getField($marcxml, '971');
            my $tnumber = getSubfield($field971, 'b');
            my $preorderdate = getSubfield($field971, 'c');

            my $year = substr($preorderdate, 0, 4);
            my $month = substr($preorderdate, 4, 2);
            my $day = substr($preorderdate, 6, 2);

            my $timestamp = timelocal('59', '59', '23', $day, $month-1, $year);

            if ($timestamp < time) {
                $writer->startTag('t-number', 'nr' => $tnumber);
                    $writer->startTag('order', 'artno' => $allfons, 
                                      'no-of-items' => $order->{quantity}, 'record' => 'y', 'bind-code' => 'y');
                    $writer->endTag();
                $writer->endTag();
            }#If order type is not addition
            else{
                $writer->startTag('addition-order', 'no-of-items' => $order->{quantity}, 'record' => 'y', 'bind-code' => 'y');
                    $writer->startTag('author');
                        $writer->characters('![CDATA['.encode('utf8', $bd->{author}).']]');
                    $writer->endTag();
                    $writer->startTag('title');
                        $writer->characters('![CDATA['.encode('utf8', $bd->{title}).']]');
                    $writer->endTag();
                    $writer->startTag('isbn');
                        $writer->characters('![CDATA['.$bd->{isbn}.']]');
                    $writer->endTag();
                $writer->endTag();
            }#If order type is addition
         }#Foreach order ends here
    }#For baskets ends here
    #Stuff ends here
    $writer->endTag();
    $writer->end();

    my $msg = MIME::Lite->new(
        From    => C4::Context->preference("KohaAdminEmailAddress"),
        To      => 'johanna.raisa@mikkeli.fi',#'johanna.raisa@mikkeli.fi',
        Subject => 'Tilaus',
        Data => 'Tilaustiedot',
        Type    => 'multipart/mixed'
    );

    $msg->attach(
        Type     => 'text/xml',
        Filename => $filename,
        Path => '/tmp/'.$filename,
        Disposition => 'attachment'
    );

    $msg->send;

    return 0;
}

sub getField {
    my ($marcxml, $tag) = @_;

    if ($marcxml =~ /^\s{2}<(data|control)field tag="$tag".*?>(.*?)<\/(data|control)field>$/sm) {
        return $2;
    }
    return 0;
}

sub getSubfield {
    my ($fieldxml, $subfield) = @_;

    if ($fieldxml =~ /^\s{4}<subfield code="$subfield">(.*?)<\/subfield>$/sm) {
        return $1;
    }
    return 0;
}

return 1;