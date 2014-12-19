#!/usr/bin/perl


# Copyright 2008 LibLime
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
#use warnings; FIXME - Bug 2505
use C4::Context;
use C4::Output;
use CGI;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Reserves;

use vars qw($debug);

BEGIN {
    $debug = $ENV{DEBUG} || 0;
}

my $input = new CGI;
my $sessionID = $input->cookie("CGISESSID");
my $session = get_session($sessionID);

my $biblionumber = $input->param('biblionumber');
my $borrowernumber = $input->param('borrowernumber');
my $reserve_id = $input->param('reserve_id');
my $transfer = $input->param('transfer');

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {   
        template_name   => "circ/printslip.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
        debug           => $debug,
    }
);

my $userenv = C4::Context->userenv;
my ($slip, $is_html);
if ( my $letter = ReserveSlip ($session->param('branch') || $userenv->{branch}, $borrowernumber, $biblionumber, $transfer, $reserve_id) ) {
    $slip = $letter->{content};
    $is_html = $letter->{is_html};
}
else {
    $slip = "Reserve not found";
}
$template->param(
    slip => $slip,
    plain => !$is_html,
    title => "Koha -- Circulation: Transfers",
    stylesheet => C4::Context->preference("SlipCSS"),
);

output_html_with_http_headers $input, $cookie, $template->output;




