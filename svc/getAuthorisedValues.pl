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

This file is a AJAX-callable wrapper for C4::Koha::GetAuthorisedValues()

Valid parameters:

category
selected
opac
branch_limit

See C4::Koha::GetAuthorisedValues() for detailed documentation.

=cut
use Modern::Perl;

use CGI;
use C4::Auth qw/check_cookie_auth/;
use JSON qw/to_json/;
use C4::Koha qw/GetAuthorisedValues/;

my $input = new CGI;

my ( $auth_status, $sessionID ) =
        check_cookie_auth(
            $input->cookie('CGISESSID'),
            { 'catalogue' => '*' } );

if ( $auth_status ne "ok" ) {
    exit 0;
}

## Getting the input parameters ##

my $category = $input->param('category');
my $selected = $input->param('selected');
my $opac = $input->param('opac');
my $branch_limit = $input->param('branch_limit');


my $avs = C4::Koha::GetAuthorisedValues($category, $selected, $opac, $branch_limit);


binmode STDOUT, ":encoding(UTF-8)";
print $input->header(
    -type => 'application/json',
    -charset => 'UTF-8'
);

print to_json( $avs);