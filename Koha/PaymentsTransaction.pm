package Koha::PaymentsTransaction;

# Copyright Open Source Freedom Fighters
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
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
use Data::Dumper;

use C4::Accounts;
use C4::Context;
use C4::Log;
use C4::Stats;

use Koha::Database;

use bignum;

use base qw(Koha::Object);

sub type {
    return 'PaymentsTransaction';
}

sub AddRelatedAccountline {
    my ($self, $accountlines_id, $paid_price) = @_;

    return 0 unless defined $accountlines_id and defined $paid_price;

    my $dbh = C4::Context->dbh;
    my $sql = "INSERT INTO payments_transactions_accountlines (transaction_id, accountlines_id, paid_price_cents) VALUES (?, ?, ?)";

    my $sth = $dbh->prepare($sql);
    $sth->execute($self->transaction_id, $accountlines_id, $paid_price);

    return $dbh->last_insert_id(undef,undef,'payments_transactions_accountlines',undef);
}

sub GetRelatedAccountlines {
    my ($self) = @_;

    my $dbh = C4::Context->dbh;
    my $sql = "SELECT accountlines.accountlines_id, accountlines.amountoutstanding, accountlines.accountno, payments_transactions_accountlines.paid_price_cents, payments_transactions_accountlines.transaction_id, accountlines.description, accountlines.itemnumber FROM accountlines INNER JOIN payments_transactions_accountlines
ON payments_transactions_accountlines.accountlines_id = accountlines.accountlines_id AND payments_transactions_accountlines.transaction_id=?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($self->transaction_id);

    my $hash_ref = $sth->fetchall_arrayref({});
    $sth->finish;
    return $hash_ref;
}

sub GetProducts {
    my ($self) = @_;

    my $dbh = C4::Context->dbh;
    my $sql = "SELECT accountlines.accounttype, payments_transactions_accountlines.paid_price_cents, accountlines.description FROM accountlines INNER JOIN payments_transactions_accountlines
ON payments_transactions_accountlines.accountlines_id = accountlines.accountlines_id AND payments_transactions_accountlines.transaction_id=?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($self->transaction_id);

    my @products;

    while (my $accountline = $sth->fetchrow_hashref) {
        my $product;
        $product->{Code} = $accountline->{'accounttype'};
        $product->{Price} = $accountline->{'paid_price_cents'};
        $product->{Description} = $accountline->{'description'};
        push @products, $product;
    }

    return \@products;
}

=head2 CompletePayment

  &CompletePayment($transaction_number);

Completes the payment in Koha from the given transaction number.

This subroutine will be called twice after payment is completed:
    1. After response from long-polling AJAX-call at paycollect.pl
    2. After payment report is received to REST API
It is important that these two cases don't use the database at the
exact same moment. Otherwise both could interpret that the payment
is still incomplete, and will attempt to complete it! This would lead
to double-Pay events in Koha. We will solve this issue by locking the
payments_transactions table until one instance has read the current
status of the payment and marked the payment as "processing". From this
on all other instances will see that the payment is either "processing"
or already has the same status as the instance is trying to set, which
means that there is no reason to continue anymore - payment is already
completed.

=cut

sub CompletePayment {
    my ($self, $status) = @_;
    my $dbh                 = C4::Context->dbh;
    my $manager_id          = 0;
    $manager_id             = C4::Context->userenv->{'number'} if C4::Context->userenv;
    my $branch              = C4::Context->userenv->{'branch'} if C4::Context->userenv;
    my $description = "";
    my $itemnumber;
    my $old_status;
    my $new_status;

    my $transaction = $self;
    return if not $transaction;

    if ($transaction->status eq $status->{status}) {
        return;
    }

    # FAILSAFE - Run the code under eval block. If something goes wrong, release MySQL locks.
    eval {
        # It's important that we don't process this subroutine twice at the same time!
        # Lock the table and refresh Koha Object
        $dbh->do("LOCK TABLES payments_transactions WRITE, payments_transactions AS me WRITE");
        $transaction = Koha::PaymentsTransactions->find($transaction->transaction_id);

        $old_status = $transaction->status;
        $new_status = $status->{status};

        if ($old_status eq $new_status){
            # trying to complete with same status, makes no sense
            $dbh->do("UNLOCK TABLES");
            die("Old payment status == new payment status, no reason to continue")
        }

        if ($old_status ne "processing"){
            $transaction->set({ status => "processing" })->store();
            $dbh->do("UNLOCK TABLES");
        } else {
            # Another process is already processing the payment
            $dbh->do("UNLOCK TABLES");
            die("Another process is already processing the payment");
        }
    };
    if ($@) {
        # In case of some issue, make sure the table doesn't stay locked.
        $dbh->do("UNLOCK TABLES");
        return; # Something went wrong. We don't want to continue.
    }

    # Defined accountlines_id means that the payment is already completed in Koha.
    # We don't want to make duplicate payments. So make sure it is not defined!
    #return if defined $transaction->accountlines_id;
    # Reverse the payment if old status is different than new status (and either paid or cancelled)
    if (defined $transaction->accountlines_id && (($old_status eq "paid" and $new_status eq "cancelled") or ($old_status eq "cancelled" and $new_status eq "paid"))){
        C4::Accounts::ReversePayment($transaction->accountlines_id);
        $transaction->set($status)->store();
        return;
    }

    # Payment was cancelled
    if ($new_status eq "cancelled") {
        $transaction->set({ status => "cancelled" })->store();
        &logaction(
        "PAYMENTS",
        "PAY",
            $transaction->transaction_id,
            $transaction->status
        );
        return;
    }

    # If transaction is found, pay the accountlines associated with the transaction.
    my $accountlines = $transaction->GetRelatedAccountlines();

    # Define a variable for leftovers. This should not be needed, but it's a fail-safe.
    my $leftovers = 0;

    my $sth = $dbh->prepare('UPDATE accountlines SET amountoutstanding= ? ' .
        'WHERE accountlines_id=?');

    my @ids;
    foreach my $acct (@$accountlines){
        if (_convert_to_cents($acct->{amountoutstanding}) == 0) {
            $leftovers += _convert_to_euros($acct->{paid_price_cents});
            next;
        }

        my $paidamount = _convert_to_euros($acct->{paid_price_cents});
        my $newamount = 0;

        $itemnumber = $acct->{itemnumber} if @$accountlines == 1;

        if ($acct->{amountoutstanding} >= $paidamount) {
            $newamount = $acct->{amountoutstanding}-$paidamount;
        }
        else {
            $leftovers += $paidamount-$acct->{amountoutstanding};
        }

        $sth->execute( $newamount, $acct->{accountlines_id} );

        $description .= ((length($description) > 0) ? "\n" : "") . $acct->{description};

        if ( C4::Context->preference("FinesLog") ) {
            C4::Log::logaction("FINES", 'MODIFY', $transaction->borrowernumber, Dumper({
                action                => 'fee_payment',
                borrowernumber        => $transaction->borrowernumber,
                old_amountoutstanding => $acct->{'amountoutstanding'},
                new_amountoutstanding => $newamount,
                amount_paid           => $paidamount,
                accountlines_id       => $acct->{'accountlines_id'},
                accountno             => $acct->{'accountno'},
                manager_id            => $manager_id,
            }));
            push( @ids, $acct->{'accountlines_id'} );
        }
    }

    if ($leftovers > 0) {
        C4::Accounts::recordpayment_selectaccts($transaction->borrowernumber, $leftovers, [], "Leftovers from transaction ".$transaction->transaction_id);
        $transaction->set({ status => $new_status })->store();
    }

    if ($transaction->price_in_cents-_convert_to_cents($leftovers) > 0) {
        my $nextacctno = C4::Accounts::getnextacctno($transaction->borrowernumber);
        # create new line
        my $sql = 'INSERT INTO accountlines ' .
        '(borrowernumber, accountno,date,amount,description,accounttype,amountoutstanding,itemnumber,manager_id,note) ' .
        q|VALUES (?,?,now(),?,?,'Pay',?,?,?,?)|;
        $dbh->do($sql,{},$transaction->borrowernumber, $nextacctno , (-1)*_convert_to_euros($transaction->price_in_cents-_convert_to_cents($leftovers)), $description, 0, $itemnumber, $manager_id, $transaction->description);

        $transaction->set({ status => $new_status, accountlines_id => $dbh->last_insert_id( undef, undef, 'accountlines', undef ) })->store();

        C4::Stats::UpdateStats($branch, 'payment', _convert_to_euros($transaction->price_in_cents), '', '', '', $transaction->borrowernumber, $nextacctno);

        if ( C4::Context->preference("FinesLog") ) {
            C4::Log::logaction("FINES", 'CREATE',$transaction->borrowernumber,Dumper({
                action            => 'create_payment',
                borrowernumber    => $transaction->borrowernumber,
                accountno         => $nextacctno,
                amount            => 0 - _convert_to_euros($transaction->price_in_cents),
                amountoutstanding => 0 - $leftovers,
                accounttype       => 'Pay',
                accountlines_paid => \@ids,
                manager_id        => $manager_id,
            }));
        }
        &logaction(
        "PAYMENTS",
        "PAY",
            $transaction->transaction_id,
            $transaction->status
        );
    }
}

=head2 RevertPayment

  &RevertPayment();

Reverts the already completed payment.

=cut

sub RevertPayment {
    my ($self) = @_;
    my $dbh                 = C4::Context->dbh;

    my $transaction = $self;

    return if not $transaction;

    return if not defined $transaction->accountlines_id;

    C4::Accounts::ReversePayment($transaction->accountlines_id);
}


sub _convert_to_cents {
    my ($price) = @_;

    return int($price*100); # transform into cents
}

sub _convert_to_euros {
    my ($price) = @_;

    return $price/100;
}
1;