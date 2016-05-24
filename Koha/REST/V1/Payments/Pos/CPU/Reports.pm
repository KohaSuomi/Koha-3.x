package Koha::REST::V1::Payments::Pos::CPU::Reports;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';

use Koha::Logger;
use Koha::Payment::POS;
use Koha::PaymentsTransaction;
use Koha::PaymentsTransactions;

use Data::Dumper;

=head2 CPU_report($c, $args, $cb)

Receives the success report from CPU.

=cut
sub cpu_report {
    my ($c, $args, $cb) = @_;

    my $invoicenumber = $args->{'invoicenumber'};
    $args = $args->{body};

    C4::Context->interface('intranet');
    my $logger = Koha::Logger->get({ category=> 'Koha.REST.V1.Payments.Pos.CPU.Reports.cpu_report' });
    $logger->info("Report received: ".Dumper($args));

    my $transaction = Koha::PaymentsTransactions->find($invoicenumber);
    $logger->warn("Transaction $invoicenumber not found.") if not $transaction;
    return $c->$cb({ error => "Transaction not found"}, 404) if not $transaction;

    my $interface = Koha::Payment::POS->new($transaction->user_branch);
    my $valid_hash = $interface->is_valid_hash($args);
    $logger->warn("Invalid hash for transaction $invoicenumber.") if not $valid_hash;
    return $c->$cb({ error => "Invalid Hash" }, 400) if not $valid_hash;

    $interface->complete_payment($args);

    return $c->$cb("", 200);
}

1;
