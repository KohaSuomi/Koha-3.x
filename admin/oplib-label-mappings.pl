#!/usr/bin/perl
# copyright 2014 Vaara-kirjastot
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
use CGI;

use C4::OPLIB::Labels;
use C4::ItemType qw/all/;
use C4::Output;
use C4::Auth;
use C4::Koha qw/GetAuthorisedValues/;
use C4::Branch qw/GetBranchesLoop/;

my $cgi = CGI->new;
my $dbh = C4::Context->dbh;

# my $flagsrequired;
# $flagsrequired->{circulation}=1;
my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "admin/oplib-label-mappings.tt",
                            query => $cgi,
                            type => "intranet",
                            authnotrequired => 0,
                            flagsrequired => {parameters => 'manage_circ_rules'},
                            debug => 1,
                            });

my $op = $cgi->param('op') || q{};

# save the values entered
if ($op eq 'add') {
    my $olm = $cgi->Vars();
    C4::OPLIB::Labels::upsertMapping( $olm );
}
if ($op eq 'delete') {
    my $olm = $cgi->Vars();
    C4::OPLIB::Labels::deleteMapping( $olm );
}


my $itemtypes = [ C4::ItemType->all() ];
my $locations = C4::Koha::GetAuthorisedValues('LOC');
my $ccodes = C4::Koha::GetAuthorisedValues('CCODE');
my $branches = C4::Branch::GetBranchesLoop();
my $mappings = C4::OPLIB::Labels::getMappings();

$template->param(       locations => $locations,
                        itemtypes => $itemtypes,
                        ccodes => $ccodes,
                        mappings => $mappings,
                        branches => $branches,
                );

output_html_with_http_headers $cgi, $cookie, $template->output;

exit 0;