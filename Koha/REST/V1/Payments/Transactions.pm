package Koha::REST::V1::Payments::Transactions;

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';

use C4::Log;

use Koha::PaymentsTransaction;
use Koha::PaymentsTransactions;

sub get_transaction {
    my ($c, $args, $cb) = @_;

    return $c->$cb({ error => "Missing transaction number"}, 400) if not $args->{'invoicenumber'};

    # Find transaction
    my $transaction = Koha::PaymentsTransactions->find($args->{invoicenumber});

    return $c->$cb({ error => "Transaction not found"}, 404) if not $transaction;
    
    return $c->$cb({
                    transaction_id        => $transaction->transaction_id,
                    borrowernumber        => int($transaction->borrowernumber),
                    status                => $transaction->status,
                    timestamp             => $transaction->timestamp,
                    description           => $transaction->description || "",
                    price_in_cents => int($transaction->price_in_cents),
                    }, 200);
}

1;