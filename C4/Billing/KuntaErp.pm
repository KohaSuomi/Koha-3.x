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
use Net::FTP;
use Data::Dumper;

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

    my $added = C4::Billing::KuntaErp::SendXMLData($borrowernumber, $dir, @accounts);

@PARAMS $borrowernumber, $dir, @accounts
@RETURNS A true value.
=cut

sub SendXMLData {

	my ($borrowernumber, $dir, @accountlines) = @_;

	#get borrower details
	my $member = GetMember( 'borrowernumber' => $borrowernumber );

	my $xsd = $dir.'ORDERS05.ZORDERS5.xsd';

	my $schema = XML::Compile::Schema->new($xsd);

	my $hash = MLI_Hash($member, @accountlines);

	my $write  = $schema->compile(WRITER => 'ZORDERS5');

	my $dom = XML::LibXML::Document->new( '1.0', 'UTF-8' );

    my $xml = $write->($dom, $hash);

	$dom->setDocumentElement($xml);

	my $timestamp = time();

	open my $out, '>>', '/home/ubuntu/xml/sendinvoice'.$timestamp.'.xml' or die("Can't open file  : $!");
	binmode $out; # as above
	print {$out} $dom->toString(1);

	my $providerConfig = {host=>'', user=>'', pw=>''}; # For testing, need to add these to secure place before pushing to git.

	#Get the ftp-connection.
	#FIXME: Probably needs NAT to allow connection to ftp. Can't do while updating part records.
    my ($ftpcon, $error) = _getFtp($providerConfig);
    warn $error;
    if ($error) {
        return(undef, $error);
    } else {
    	return 1;
    }

	
}

sub MLI_Hash {

	my ($member, @accountlines) = @_;

	my $data = {IDOC => []};
	foreach my $accountline (@accountlines){
		#get account details
		my $accts = GetAccountlineDetails($accountline);
		my $hash =
      			{
      				BEGIN => 1,
      				EDI_DC40 => 
      				{
      					SEGMENT => 1,
      					DIRECT => 1,
      					SNDPOR => $member->{'surname'},
      					SNDPRT => "",
      					SNDPRN => "",
      					RCVPOR => $accts->{'amount'},
      					RCVPRN => "",
      				},
      				E1EDK01 => {
      					SEGMENT => "1",
      				},
      				E1EDK14 => {
      					SEGMENT => "1",
      				},
      				E1EDPT1 => {
      					SEGMENT => "1",
      					E1EDPT2 =>{
      						SEGMENT => "1",
      						TDLINE => "hep",
      					}
      				},
      			};
      	push (@{$data->{IDOC}}, $hash);

	}

    return ($data);
	
}

sub _getFtp {

	my ($providerConfig) = @_;

    my $ftpcon = Net::FTP->new( Host => $providerConfig->{host},
                                Timeout => 10);
    unless ($ftpcon) {
        return (undef, "Cannot connect to ftp server: $@");
    }

    if ($ftpcon->login($providerConfig->{user},$providerConfig->{pw})){
        return ($ftpcon, undef);
    }
    else {
        return (undef, "Cannot login to ftp server: $@");
    }
}

END { }    # module clean-up code here (global destructor)

1;
__END__
