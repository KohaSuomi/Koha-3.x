#!/usr/bin/perl

# Displays sent notices for a given borrower

# Copyright (c) 2009 BibLibre
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
use C4::Auth;
use C4::Output;
use CGI;
use C4::Members;
use C4::Branch;
use C4::Letters;
use C4::Members::Attributes qw(GetBorrowerAttributes);

use C4::Dates qw/format_date/;
my $input=new CGI;


my $borrowernumber = $input->param('borrowernumber');
#get borrower details
my $borrower = GetMember(borrowernumber => $borrowernumber);

my ($template, $loggedinuser, $cookie)
= get_template_and_user({template_name => "members/notices.tmpl",
				query => $input,
				type => "intranet",
				authnotrequired => 0,
				flagsrequired => {borrowers => 1},
				debug => 1,
				});

my $op = $input->param('op') || q||;

$template->param( $borrower );
my ($picture, $dberror) = GetPatronImage($borrower->{'borrowernumber'});
$template->param( picture => 1 ) if $picture;

$template->param( %{$borrower} );

# Allow resending of messages in Notices tab
if ( $op eq 'resend_notice' ) {
    my $message_id = $input->param('message_id');
    my $message = C4::Letters::GetMessage( $message_id );
    if ( $message->{borrowernumber} = $borrowernumber ) {
        C4::Letters::ResendMessage( $message_id );
        # redirect to self to avoid form submission on refresh
        print $input->redirect("/cgi-bin/koha/members/notices.pl?borrowernumber=$borrowernumber");
    }
}

# Getting the messages
my $queued_messages = C4::Letters::GetQueuedMessages({borrowernumber => $borrowernumber});

if (C4::Context->preference('ExtendedPatronAttributes')) {
    my $attributes = GetBorrowerAttributes($borrowernumber);
    $template->param(
        ExtendedPatronAttributes => 1,
        extendedattributes => $attributes
    );
}

$template->param(
			QUEUED_MESSAGES 	=> $queued_messages,
			borrowernumber 		=> $borrowernumber,
			sentnotices 		=> 1,
                        branchname              => GetBranchName($borrower->{'branchcode'}),
                        categoryname            => $borrower->{'description'},
			activeBorrowerRelationship => (C4::Context->preference('borrowerRelationship') ne ''),
            RoutingSerials => C4::Context->preference('RoutingSerials'),
);
output_html_with_http_headers $input, $cookie, $template->output;

