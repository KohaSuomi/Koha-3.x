package C4::Billing::KuntaErp;

# Copyright 2015 Lumme-kirjastot
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

use Modern::Perl;

use XML::LibXML;
use XML::Compile::Schema;
use C4::Members;
use C4::Accounts;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
	# set the version for version checking
    $VERSION = 1.0;
	require Exporter;
	@ISA    = qw(Exporter);
	@EXPORT = qw(
		&SendXMLData
	);
}



=head SendXMLData

    my $added = C4::Billing::KuntaErp::SendXMLData($params);

@PARAM1 Hash of koha.aqbookseller, the bookseller for whom to find the proper interface code.
@RETURNS String, the interface code to tell which interface to use.
                 Can be 'KV' or 'BTJ' or undef if no interface defined.
=cut

sub SendXMLData {

	my ($borrowernumber, $accountlines_id) = @_;

	#get borrower details
	my $member = GetMember( 'borrowernumber' => $borrowernumber );

	#get account details
	my ( $total, $accts, $numaccts ) = GetMemberAccountRecords($borrowernumber);
	my $totalcredit;
	if ( $total <= 0 ) {
    	$totalcredit = 1;
	}

	my $xsd = '/home/ubuntu/xml/ORDERS05.ZORDERS5.xsd';

	my $schema = XML::Compile::Schema->new($xsd);

	my $write  = $schema->compile(WRITER => 'ZORDERS5');

	my $dom = XML::LibXML::Document->new( '1.0', 'UTF-8' );

	my $hash = Hash($member, $accts);

	my $xml = $write->($dom, $hash);

	$dom->setDocumentElement($xml);

	my $timestamp = time();

	open my $out, '>>', '/home/ubuntu/xml/sendinvoice'.$timestamp.'.xml' or die("Can't open file  : $!");
	binmode $out; # as above
	print {$out} $dom->toString(1);

	return 1;
}

sub Hash {

	my ($member, $accts) = @_;
	my $data = {
      		IDOC => [
      			{
      				BEGIN => '1',
      				EDI_DC40 => 
      				{
      					SEGMENT => '1',
      					DIRECT => '1',
      					SNDPOR => $member->{'surname'},
      					SNDPRT => "",
      					SNDPRN => "",
      					RCVPOR => sprintf( "%.2f", $accts->[1]{'amount'} ),
      					RCVPRN => "",
      				},
      				E1EDK01 => {
      					SEGMENT => '1',
      				},
      				E1EDK14 => {
      					SEGMENT => '1',
      				},
      				E1EDPT1 => {
      					SEGMENT => '1',
      					E1EDPT2 =>{
      						SEGMENT => '1',
      						TDLINE => 'hep',
      					}
      				},
      			}
      		]
      	};

    return ($data);
}

END { }    # module clean-up code here (global destructor)

1;
__END__
