#!/usr/bin/perl


#writen 11/1/2000 by chris@katipo.oc.nz
#script to display borrowers account details


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

# LUMME #103
# Billing interface for sending invoices

use strict;
use warnings;

use C4::Auth;
use C4::Output;
use C4::Dates qw/format_date/;
use CGI;
use C4::Members;
use C4::Branch;
use C4::Accounts;
use C4::Billing::KuntaErp;

my $input = new CGI;

my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "members/boraccount.tmpl",
                            query => $input,
                            type => "intranet",
                            authnotrequired => 0,
                            flagsrequired => {borrowers => 1, updatecharges => 'remaining_permissions'},
                            debug => 1,
                            });

my $branchcode = $input->param('branchcode');
my $borrowernumber  = $input->param('borrowernumber');
my $accountlines_id = $input->param('accountlines_id');

my $branch = GetBranchDetail($branchcode);
my $added = 0;

if ($branch->{'accountbilling'} eq 'KuntaErp') {

	$added = SendXMLData($borrowernumber, $accountlines_id);

  	if ($added) {
  		print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber&sentinvoice=1");
  	}

	
} else {
	print $input->redirect("/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
}	