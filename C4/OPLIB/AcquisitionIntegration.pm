package C4::OPLIB::AcquisitionIntegration;

# Copyright 2015 Vaara-kirjastot
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

use POSIX qw/strftime/;
use YAML::XS;

use Net::FTP;
use Scalar::Util qw( blessed );
use Try::Tiny;
use Koha::Exception::NoSystemPreference;
use Koha::Exception::BadSystemPreference;
use Koha::Exception::ConnectionFailed;
use Koha::Exception::LoginFailed;
use Koha::Exception::UnknownProtocol;
use Koha::FTP;

use C4::Bookseller qw/GetBookSellerFromId/;
use C4::Budgets qw/ConvertCurrency/;
use C4::Acquisition qw/GetOrders GetBasketsByBasketgroup GetBasketgroup GetBasket ModBasketgroup/;
use C4::Bookseller qw/GetBookSellerFromId/;
use C4::Branch qw/GetBranches/;
use C4::Members qw/GetMember/;
use C4::Contract qw/GetContract/;
use C4::Biblio qw/GetBiblioData/;
use C4::OPLIB::VendorConfig;

=head sendBasketgroupToVendors

    C4::OPLIB::AcquisitionIntegration::SendBasketgroupToVendors($basketgroupid);

Takes a $basketgroupid, and finds all of it's baskets. Then selects, based on the baskets $bookseller name or url, which
interface to use to send the order to the basket's vendor.
Currently supported vendors:
  Kirjavälitys, sending an .csv-file using pftp.

@PARAM1, Long, the aqbasketgroups.basketgroupid, whose baskets to order.
@RETURNS, List of Strings, the possible errors or undef.
=cut

sub SendBasketgroupToVendors {
    my $basketgroupid = shift;
    my $basketgroup = GetBasketgroup( $basketgroupid );

    my $csvBuilder_kirjavalitys = [];
    my $errorsBuilder = []; #Collect all found errors, if errors, prevent sending the csv, instead print a summary of errors.

    my $baskets = GetBasketsByBasketgroup($basketgroupid);

    for my $basket (@$baskets) {
        my $orders     = [ GetOrders( $$basket{basketno} ) ];
        my $contract   = GetContract( $$basket{contractnumber} );
        my $bookseller = GetBookSellerFromId( $$basket{booksellerid} );

        my $interfaceCode = GetOrderInterface($bookseller);
        if ($interfaceCode eq 'KV') {
            queueBasketToKirjavalitysAsCsv($csvBuilder_kirjavalitys, $basket, $orders, $contract, $bookseller, $basketgroup, $errorsBuilder);
        }
        elsif ($interfaceCode eq 'BTJ') {
            push @$errorsBuilder, "There is no automatic mechanism for sending orders to BTJ.\nYou need to print this basketgroup as a .pdf and send it by email.";
        }
        elsif (not($interfaceCode)) {
            push @$errorsBuilder, "Couldn't decide where to send this order. There is no configured interface for the given vendor.\nYou need to print this basketgroup as a .pdf and send it by email.";
        }
        else {
            push @$errorsBuilder, "Something very strange hapened with GetOrderInterface()! Please notify your friendly Koha administrator.\nHowever there is no configured interface for the given vendor.\nYou need to print this basketgroup as a .pdf and send it by email.";
        }
    }

    if (@$errorsBuilder == 0) {

        #If we have orders for KV, then send them away!
        if (scalar(@$csvBuilder_kirjavalitys) > 0) {
            if (sendCsvToKirjavalitys($csvBuilder_kirjavalitys, $basketgroup, $errorsBuilder)) {
                markBasketgroupAsOrdered( $basketgroup );
            }
        }
    }

    if (@$errorsBuilder != 0) {
        return $errorsBuilder;
    }
    return undef; #All is well and peace in the kingdom!
}

sub queueBasketToKirjavalitysAsCsv {
    my ($csvBuilder, $basket, $orders, $contract, $bookseller, $basketgroup, $errorsBuilder) = @_;

    my @extractedOrderValues;
    foreach my $order (@$orders) {
        my $bd = GetBiblioData( $order->{'biblionumber'} );

        my $product_id = ""; #This is either ISBN or ISSN or EAN
        if (my $f020a = getSubfieldFromMARCXML($bd,'020','a')) {
            $product_id = $f020a;
        } elsif (my $f024a = getSubfieldFromMARCXML($bd,'024','a')) {
            $product_id = $f024a;
        }

        ## Sanitize values
        my $row = {};
        if ($product_id && $product_id =~ /(\d+)/) {
            $row->{product_id} = $1;
        }else {
            push @$errorsBuilder, 'Basketname '.$basket->{basketname}.' order no. '.$order->{ordernumber}.' has a bad ISBN/ISSN/EAN '.$product_id;
        }
        if ($bookseller->{accountnumber}) {
            $row->{clientnumber} = $bookseller->{accountnumber};
        }else {
            push @$errorsBuilder, 'Basketname '.$basket->{basketname}.' order no. '.$order->{ordernumber}.' has no Kirjavälitys customer number';
        }
        if ($order->{quantity}) {
            $row->{quantity} = $order->{quantity};
        }else {
            push @$errorsBuilder, 'Basketname '.$basket->{basketname}.' order no. '.$order->{ordernumber}.' has no quantity?!';
        }
        if ($basketgroup && $basketgroup->{id}) {
            $row->{invoice} = 'vk'.$basketgroup->{id}.'kv';
        }else {
            push @$errorsBuilder, 'Basketname '.$basket->{basketname}.' order no. '.$order->{ordernumber}.' has no basketgroupid, this is impossible :) ?!';
        }

        push @extractedOrderValues, $row;
    }


    ## Build the csv!
    foreach my $eov (@extractedOrderValues) {
        if (@$csvBuilder == 0) { #Build the csv-header when the csv-file is empty (has no content queued)
            my @keys = sort keys %$eov;
            push @$csvBuilder, join ',',@keys;
        }

        #Build the csv row!
        my @keys = sort keys %$eov;
        my @values = map {$eov->{$_}} @keys;
        push @$csvBuilder, join ',',@values;
    }
}

=head sendCsvToKirjavalitys

    sendCsvToKirjavalitys( $csvBuilder, $basketgroup, $errorsBuilder );

Sends the prepared .csv-file to Kirjavälitys using pftp.

@PARAM1, Array of Strings, the list of .csv-rows containing orderline information. Generated using
         queueBasketToKirjavalitysAsCsv().
@PARAM2, Hash of koha.aqbasketgroup, the basketgroup to send.
@PARAM3, Array of Strings, the StringBuilder for error notifications to be propagated to the UI.
=cut

sub sendCsvToKirjavalitys {
    my $csvBuilder = shift;
    my $basketgroup = shift;
    my $errorsBuilder = shift; #Collect all errors here for propagation to the UI
    my $now = strftime('%Y%m%d',localtime);

    ##Build the temporary csv for sending
    my $file = '/tmp/jokunen_order_'.$now.'_basketgroup_'.$basketgroup->{'id'}.'.csv';
    my $ok = open(my $CSV, ">:encoding(latin1)", $file);
    unless($ok) {
        push @$errorsBuilder, "Couldn't write to the temp file $file for sending to Kirjavälitys";
        return undef;
    }
    print $CSV join "\n",@$csvBuilder;
    close $CSV;

    ##Send it away!
    my $ftpcon;
    try {
        $ftpcon = connectToKirjavalitys();
    } catch {
        push @$errorsBuilder, $_->error();
    };
    if ($ftpcon) {
        if (! $ftpcon->cwd('/Order') ) {
            push @$errorsBuilder, "Cannot change to the Order folder with Kirjavälitys' ftp server: $@";
            return undef;
        }

        if($ftpcon->put($file)) {
            #All is OK!
        }
        else {
            push @$errorsBuilder, "Cannot deliver the order csv $file to Kirjavälitys' ftp server: $@";
            return undef;
        }
        $ftpcon->quit;
        return 1; #Alls well and package delivered!
    }
    return undef; #Connection error :(
}

sub markBasketgroupAsOrdered {
    my $basketgroup = shift;
    my $now = strftime('%d.%m.%Y %H:%M:%S',localtime);

    my $dbh = C4::Context->dbh();

    my $sth = $dbh->prepare('UPDATE aqbasketgroups SET deliverycomment=? WHERE id=?');
    $sth->execute( "Tilattu $now\n".$basketgroup->{deliverycomment} , $basketgroup->{id} );

    ##Somebody thought that removing all baskets from a basketgroup was a good idea when a basketgroup is modified??? Le fuu!!
    #C4::Acquisition::ModBasketgroup({id => $basketgroup->{id},
    #                                 deliverycomment => "Tilattu $now\n".$basketgroup->{deliverycomment}
    #                                });
}

sub isBasketgroupOrdered {
    my $basketgroup = shift;
    if (defined $basketgroup->{'deliverycomment'} && $basketgroup->{'deliverycomment'} =~ /tilattu/i) {
        return 1;
    }
    return 0;
}

=head GetOrderInterface

    my $interface = C4::OPLIB::AcquisitionIntegration::GetOrderInterface( $bookseller );
    if ($interface eq 'KV') {#Do stuff for KV}

@PARAM1 Hash of koha.aqbookseller, the bookseller for whom to find the proper interface code.
@RETURNS String, the interface code to tell which interface to use.
                 Can be 'KV' or 'BTJ' or undef if no interface defined.
=cut

sub GetOrderInterface {
    my ($bookseller) = @_;

    ## For Kirjavälitys ##
    if ($bookseller->{name} =~ /Kirjav.litys/i ||
                $bookseller->{name} =~ /KV/ ||
                $bookseller->{url}  =~ /www.kirjavalitys.fi/) {

        return 'KV';
    }
    elsif ($bookseller->{name} =~ /BTJ/i ||
            $bookseller->{name} =~ /BTJ/ ||
            $bookseller->{url}  =~ /www.btj.fi/) {

        return 'BTJ';
    }
    else {
        return undef;
    }
}

#$bd = bibliodata, or any HASH reference with the key marcxml containing the marcxml
#$field eg. '020'
#$subfield eg. 'a'
sub getSubfieldFromMARCXML {
    my ($bd, $field, $subfield) = @_;

    if ($bd->{marcxml} =~ m|<datafield tag="$field".*?>(.*?)</datafield>|s) {
        if ($1 =~ m|<subfield code="$subfield">(.*?)</subfield>|s) {
            return $1;
        }
    }
    return 0;
}

#########################################
### Vendor service connection helpers ###
#########################################

=head connectToKirjavalitys

    try {
        my $ftpcon = connectToKirjavalitys();
    } catch {
        warn $_->to_string();
    }

@RETURNS Net::FTP, if connection succeeded.
@THROWS Koha::Exception::BadSystemPreference;
        Koha::Exception::ConnectionFailed;
        Koha::Exception::LoginFailed;
        Koha::Exception::NoSystemPreference;
        Koha::Exception::UnknownProtocol;
=cut

sub connectToKirjavalitys {
    return connectProvider('Kirjavalitys');
}

sub connectProvider {
    my ($configKey) = @_;

    my $configVendor = getVendorConfig($configKey);
    if ($configVendor->{protocol}) {
        if ($configVendor->{protocol} =~ m/ftp/) {
            return Koha::FTP::connect($configVendor, $configKey);
        }
        else {
            Koha::Exception::UnknownProtocol->throw( error =>
                "connectFtp():> Connecting to '$configKey', Unknown protocol ".$configVendor->{protocol});
        }
    }
    else {
        Koha::Exception::UnknownProtocol->throw( error =>
            "connectFtp():> Connecting to '$configKey', 'protocol' not defined. You must set the 'VaaraAcqVendorConfigurations'-syspref protocol to something nice, like protocol: \"passive ftp\"");
    }

}

sub connectToBTJselectionLists {
    return connectProvider('BTJSelectionLists');
}
sub connectToBTJbiblios {
    return connectProvider('BTJBiblios');
}

sub getVendorConfig {
    my ($configKey) = @_;

    my $configSyspref = C4::Context->preference('VaaraAcqVendorConfigurations');
    Koha::Exception::NoSystemPreference->throw( error => 'AcquisitionIntegration::connectProvider():> "VaaraAcqVendorConfigurations"-systempreference not set.' ) unless $configSyspref;
    my $config = YAML::XS::Load(
                        Encode::encode(
                            'UTF-8',
                            $configSyspref,
                            Encode::FB_CROAK
                        )
                    );
    my $configVendor = $config->{$configKey};
    Koha::Exception::BadSystemPreference->throw(
            syspref => 'VaaraAcqVendorConfigurations',
            error => join("\n",
                "connectFtp():> Connecting to '$configKey', ",
                "Couldn't load the YAML config from syspref VaaraAcqVendorConfigurations",
                'It should look like this:',
                '--- ',
                "$configKey: ",
                '    host: 10.11.12.13',
                '    port: 21',
                '    orderDirectory: /Order',
                '    password: __lol__',
                '    protocol: passive ftp',
                '    selectionListConfirmationDirectory: /marcarkisto',
                '    selectionListDirectory: /',
                '    selectionListEncoding: utf8',
                '    selectionListFormat: marcxml',
                '    username: valivalimies',
            ),
    ) unless $configVendor;
    $configVendor->{configKey} = $configKey;

    return C4::OPLIB::VendorConfig->new($configVendor);
}

return "happy happy joy joy";
