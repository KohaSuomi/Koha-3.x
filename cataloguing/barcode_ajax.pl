#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright Anonymous
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

# The purpose of this file is to generate a JSON array to update
# the Add item -form's barcode subfield without having to
# refresh the page.

use Modern::Perl;
use strict;
use warnings;

use CGI;
use C4::Auth qw/check_cookie_auth/;
use JSON qw/to_json/;
use C4::Koha qw/GetAuthorisedValues/;
use C4::Biblio qw(GetMarcFromKohaField);
use C4::Barcodes::ValueBuilder;
use C4::Dates;

use Cpanel::JSON::XS qw(encode_json decode_json);

my $input = new CGI;

my ( $auth_status, $sessionID ) =
        check_cookie_auth(
            $input->cookie('CGISESSID'),
            { 'catalogue' => '*' } );

if ( $auth_status ne "ok" ) {
    exit 0;
}

my ($dbh,$record,$tagslib,$field_number,$tabloop) = @_;
my %args;

# find today's date
($args{year}, $args{mon}, $args{day}) = split('-', C4::Dates->today('iso'));
($args{tag},$args{subfield})       =  GetMarcFromKohaField("items.barcode", '');
($args{loctag},$args{locsubfield}) =  GetMarcFromKohaField("items.homebranch", '');

my $nextnum;
my $scr;
my $barcode;

#Getting the new barcode number and saving it to hash
($nextnum, $scr) = C4::Barcodes::ValueBuilder::annual::get_barcode(\%args);
$barcode = {'nextnum' => $nextnum};

my $json = encode_json $barcode;

binmode STDOUT, ":encoding(UTF-8)";

print $input->header(
    -type => 'application/json',
    -charset => 'UTF-8'
);

print $json;