#!/usr/bin/perl

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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA
#

use Modern::Perl;

use CGI;

use C4::Output;
use C4::Auth;
use C4::Context;
use C4::Branch;
use C4::RotatingCollections;

my $query = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "rotating_collections/rotatingCollections.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { tools => 'rotating_collections' },
        debug           => 1,
    }
);

my $branchcode = $query->cookie('branch');
my $branchesLoop = GetBranchesLoop();

my $collections = GetCollections();

$template->param(
    intranetcolorstylesheet =>
      C4::Context->preference("intranetcolorstylesheet"),
    intranetstylesheet => C4::Context->preference("intranetstylesheet"),
    IntranetNav        => C4::Context->preference("IntranetNav"),

    collectionsLoop => $collections,
    branchesLoop => $branchesLoop
);

output_html_with_http_headers $query, $cookie, $template->output;
