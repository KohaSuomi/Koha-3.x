package Koha::REST::V1::Pos::CPU::Reports;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';

use C4::Log;
use C4::OPLIB::CPUIntegration;

use Koha::PaymentsTransaction;
use Koha::PaymentsTransactions;

=head2 CPU_report($c, $args, $cb)

Receives the success report from CPU.

=cut
sub cpu_report {
    my ($c, $args, $cb) = @_;

    my $invoicenumber = $args->{'invoicenumber'};
    $args = $args->{body};

    # Check that the request is valid
    return $c->$cb({ error => "Invalid Hash" }, 400) if C4::OPLIB::CPUIntegration::CalculateResponseHash($args) ne $args->{Hash};

    # Find the transaction
    my $transaction = Koha::PaymentsTransactions->find($invoicenumber);
    return $c->$cb({ error => "Transaction not found"}, 404) if not $transaction;

    my $report_status = C4::OPLIB::CPUIntegration::GetResponseString($args->{Status});
    $transaction->CompletePayment($report_status);

    return $c->$cb("", 200);
}

1;