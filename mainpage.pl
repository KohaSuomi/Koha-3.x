#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright Paul Poulain 2002
# Parts Copyright Liblime 2007
# Copyright (C) 2013  Mark Tompsett
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

use Modern::Perl;
use CGI;
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::NewsChannels; # GetNewsToDisplay
use C4::Review qw/numberofreviews/;
use C4::Suggestions qw/CountSuggestion/;
use C4::Tags qw/get_count_by_tag_status/;
use Koha::Borrower::Modifications;
use C4::Koha;

my $query = new CGI;

my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => "intranet-main.tmpl",
        query           => $query,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1, },
    }
);

my $homebranch;
if (C4::Context->userenv) {
    $homebranch = C4::Context->userenv->{'branch'};
}
my $all_koha_news   = &GetNewsToDisplay("koha",$homebranch);
my $koha_news_count = scalar @$all_koha_news;

$template->param(
    koha_news       => $all_koha_news,
    koha_news_count => $koha_news_count,
    daily_quote     => C4::Koha::GetDailyQuoteForInterface(),
);

my $branch =
  C4::Context->preference("IndependentBranches")
  && !$flags->{'superlibrarian'}
  ? C4::Context->userenv()->{'branch'}
  : undef;

my $pendingcomments    = numberofreviews(0);
my $pendingtags        = get_count_by_tag_status(0);
my $pendingsuggestions = CountSuggestion("ASKED");
my $pending_borrower_modifications =
  Koha::Borrower::Modifications->GetPendingModificationsCount( $branch );

$template->param(
    pendingcomments                => $pendingcomments,
    pendingtags                    => $pendingtags,
    pendingsuggestions             => $pendingsuggestions,
    pending_borrower_modifications => $pending_borrower_modifications,
);

#
# warn user if he is using mysql/admin login
#
unless ($loggedinuser) {
    $template->param(adminWarning => 1);
}

output_html_with_http_headers $query, $cookie, $template->output;
