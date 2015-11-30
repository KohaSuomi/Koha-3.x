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
use HTML::Entities;

use Encode;

=head3 GetBasketGroupAsXML

=over

&GetBasketGroupAsXML($basketgroupid);

Export a basket group as XML

$cgi parameter is needed for column name translation

=back

=cut

sub GetBasketGroupAsXML{
    my ($basketgroupid, $cgi) = @_;
    my $baskets = GetBasketsByBasketgroup($basketgroupid);

    #my $template = C4::Templates::gettemplate('acqui/csv/basketgroup.tmpl', 'intranet', $cgi);

    my $xml = XML::Simple->new();
    my $xml_data = {};
    my $item_count = 0;
    my $rows;
    my $data;
    my $element;
    
    my $basketgroup = GetBasketgroup( $basketgroupid );
    my $bookseller = GetBookSellerFromId( $basketgroup->{booksellerid} );
    $data = {'nr' => $bookseller->{accountnumber}, 'name' => encode('utf8', GetBranchName($basketgroup->{billingplace}))};

    for my $basket (@$baskets) {
        my @orders     = GetOrders( $$basket{basketno} );
        my $contract   = GetContract( $$basket{contractnumber} );
        #my $bookseller = GetBookSellerFromId( $$basket{booksellerid} );
        #my $basketgroup = GetBasketgroup( $$basket{basketgroupid} );
        
        foreach my $order (@orders) {
            my $bd = GetBiblioData( $order->{'biblionumber'} );
            my $marcxml = $bd->{marcxml};
            my $allfons = getField($marcxml, '001');
            if ($$basket{booksellerid} ne 388) {
                $element = 't-number';
            	$xml_data = {'nr' => ''};
	            $xml_data->{'order'} = {
	            	'artno' => $allfons, 
	            	'no-of-items' => $order->{quantity},
	            	'record' => 'y',
	            	'bind-code' => 'y'};
	        } else {
                $element = 'addition-order';
	        	$xml_data = {
	            	'no-of-items' => $order->{quantity},
	            	'record' => 'y',
	            	'bind-code' => 'y'};

	            $xml_data->{'isbn'} = ['![CDATA['.$order->{isbn}.']]'];
                $xml_data->{'title'} = ['![CDATA['.encode('utf8', $bd->{title}).']]'];
                $xml_data->{'author'} = ['![CDATA['.encode('utf8', $bd->{author}).']]'];
	        }
            # my $row = {
            #     clientnumber => $bookseller->{accountnumber},
            #     basketname => $basket->{basketname},
            #     ordernumber => $order->{ordernumber},
            #     author => $bd->{author},
            #     title => $bd->{title},
            #     publishercode => $bd->{publishercode},
            #     publicationyear => $bd->{publicationyear},
            #     collectiontitle => $bd->{collectiontitle},
            #     isbn => $order->{isbn},
            #     quantity => $order->{quantity},
            #     rrp => $order->{rrp},
            #     discount => $bookseller->{discount},
            #     ecost => $order->{ecost},
            #     notes => $order->{order_internalnote},
            #     entrydate => $order->{entrydate},
            #     booksellername => $bookseller->{name},
            #     bookselleraddress => $bookseller->{address1},
            #     booksellerpostal => $bookseller->{postal},
            #     contractnumber => $contract->{contractnumber},
            #     contractname => $contract->{contractname},
            #     basketgroupdeliveryplace => C4::Branch::GetBranchName( $basketgroup->{deliveryplace} ),
            #     basketgroupbillingplace => C4::Branch::GetBranchName( $basketgroup->{billingplace} ),
            #     basketdeliveryplace => C4::Branch::GetBranchName( $basket->{deliveryplace} ),
            #     basketbillingplace => C4::Branch::GetBranchName( $basket->{billingplace} ),
            # };

            
            push (@{$data->{$element}}, $xml_data);
         }
         
    }
    push (@{$rows->{customer}}, $data);
    warn "XML DATA:\n" . Dumper($rows);
    my $xml_out = $xml->XMLout($rows, rootName => undef);

    return $xml_out;
}

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
            if ($bookseller->{contnotes} ne 'addition') {
                $writer->startTag('t-number', 'nr' => '');
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

return 1;