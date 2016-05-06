#!/usr/bin/perl

# Copyright KohaSuomi 2016
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
use Number::Format;
use Scalar::Util qw(looks_like_number);

use CGI qw(:cgi-lib);

use C4::Accounts;
use C4::Auth;
use C4::Branch;
use C4::Budgets qw(GetCurrency);
use C4::Circulation;
use C4::Members;
use C4::Output;

use C4::OPLIB::CPUIntegration;
use Data::Dumper;
my $query = new CGI;
my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-paycollect.tmpl",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        debug           => 1,
    }
);

# get borrower information ....
my $borr = C4::Members::GetMemberDetails( $borrowernumber );
my @bordat;
$bordat[0] = $borr;

$template->param( BORROWER_INFO => \@bordat );


my ( $total_due, $accts, $numaccts ) = C4::Members::GetMemberAccountRecords($borrowernumber);
my $minimumSum = C4::Context->preference("OnlinePaymentMinTotal");

if (not C4::OPLIB::CPUIntegration->isOnlinePaymentsEnabled(C4::Branch::mybranch())) {
    $template->param(
        NotPaid => 1,
        NotEnabled => 1,
    );
    output_html_with_http_headers $query, $cookie, $template->output;
} elsif ($query->param("Hash")) { # Check if we are returning to this page from CPU
    my $transaction = Koha::PaymentsTransactions->find($query->param("Id"));

        $template->param(transaction => $transaction) if $transaction;
        $template->param(
                         error => "TRANSACTION_NOT_FOUND",
                         ) if not $transaction;
        $template->param(error => "INVALID_HASH") if $query->param("Hash") ne C4::OPLIB::CPUIntegration::CalculateResponseHash({ $query->Vars() });

    if ($query->param("Hash") eq C4::OPLIB::CPUIntegration::CalculateResponseHash({ $query->Vars() })) {
        $transaction->set({ status => "paid" })->store() if ($query->param("Status") == 1);
        $transaction->set({ status => "cancelled" })->store() if ($query->param("Status") == 0);
    }
        output_html_with_http_headers $query, $cookie, $template->output;
} elsif ($total_due <= 0 || $total_due < $minimumSum) { # Validate total_due to make sure there is something to pay
    $template->param(
        paid => $total_due,
        NotPaid => 1,
        minimumSum => $minimumSum,
    );
    output_html_with_http_headers $query, $cookie, $template->output;
}
else {
    # Create new self-payment_transaction
    my $transaction = Koha::PaymentsTransaction->new()->set({
        borrowernumber      => $borrowernumber,
        status              => "unsent",
        description         => '',
        is_self_payment     => 1,
        user_branch         => C4::Branch::mybranch(),
    })->store();

    # Link accountlines to the transaction
    $transaction->AddRelatedAccountlines({
        paid        => $total_due,
    });

    # Get CPU payment
    my $CPUPayment = C4::OPLIB::CPUIntegration::InitializePayment({
                    transaction => $transaction
    });

    # Send CPU payment
    my $response = C4::OPLIB::CPUIntegration::SendPayment($CPUPayment);


    my $format = new Number::Format(-decimal_point => '.');
    my $paid_format = $format->format_number($total_due, 2, 2) . " " . C4::Budgets::GetCurrency()->{'currency'};
    $template->param(
        paid        => $total_due,
        paid_format => $paid_format,
        CPUPayment  => Dumper($CPUPayment),
        response => JSON::decode_json($response),
    );

    output_html_with_http_headers $query, $cookie, $template->output;
}
