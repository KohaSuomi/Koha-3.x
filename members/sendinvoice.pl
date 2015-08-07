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
use C4::Context;
use C4::Members;
use C4::Branch;
use C4::Accounts;
use C4::Billing::KuntaErp;
use Data::Dumper;

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
my $borrowernumber;
my $accountlines_id = $input->param('accountlines_id');
my @accountlines = $input->param('accountlines[]');

my $kuntaErp = 0;
my $added = 0;
my @accounts;

my $dir = C4::Context->config('intrahtdocs') . '/prog/' . $template->{lang} . '/data/';

foreach my $accountline ( @accountlines ) {
	my $data = GetAccountlineDetails($accountline);
	my $branch = GetBranchDetail($data->{'branchcode'});

	if ($branch->{'accountbilling'} eq 'KuntaErp') {
		$borrowernumber = $data->{'borrowernumber'};
		push @accounts, $data->{'accountlines_id'};
		$kuntaErp = 1;
	}
}

if ($kuntaErp) {
	$added = SendXMLData($borrowernumber, $dir, @accounts);
	print $input->header('text/html');
	print $added;
} else {
	print $input->header('text/html');
	print $added;
}