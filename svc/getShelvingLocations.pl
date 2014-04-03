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

=head SYNOPSIS

Gets the shelving locations and the Koha-to-MARC-mapping on demand.
Returns a JSON hash.

Valid parameters:

branch - The branchcode, eg CPL, FFL, JNS
framework - The Framework code or don't define. Returns the field and subfield for the shelving location defined in the given framework code
          eg. ACQ, BKS.
          Reverts to the default framework if defined as 0 (zero).

=cut
use Modern::Perl;

use CGI;
#use C4::Auth qw/check_cookie_auth/;
use JSON qw/to_json/;
use C4::Koha qw/GetAuthorisedValues/;
use C4::Biblio qw(GetMarcFromKohaField);

my $input = new CGI;

#No need to authenticate since shelving locations are quite public.
#my ( $auth_status, $sessionID ) =
#        check_cookie_auth(
#            $input->cookie('CGISESSID'),
#            { 'catalogue' => '*' } );
#
#if ( $auth_status ne "ok" ) {
#    exit 0;
#}

## Getting the input parameters ##

my $branch = $input->param('branch');
my $framework = $input->param('framework'); #The MARC framework

#shloc as shelving location, not to be mixed with http://www.schlockmercenary.com/
my $shlocs = C4::Koha::GetAuthorisedValues('LOC', undef, undef, $branch);
my ( $shloc_field, $shloc_subfield );

my $ret = {}; #Prepare the return value.

if (defined $framework) {
    ( $ret->{field}, $ret->{subfield} ) = C4::Biblio::GetMarcFromKohaField( "items.location", $framework );
}

#Build a sane return value, don't bash around huge JSON blobs needlessly!
my $ret_locations = $ret->{locations} = {}; #Create a reference point so locations-hash need not be dereferenced for each iteration of @$shloc
foreach my $av (@$shlocs) {
    $ret_locations->{ $av->{authorised_value} } = $av->{lib};
}

binmode STDOUT, ":encoding(UTF-8)";

print $input->header(
    -type => 'application/json',
    -charset => 'UTF-8'
);

print to_json( $ret);