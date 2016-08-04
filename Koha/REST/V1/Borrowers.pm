package Koha::REST::V1::Borrowers;

use Modern::Perl;
use Scalar::Util qw(blessed);
use Try::Tiny;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;

use File::Basename;

use Koha::Borrowers;
use Koha::Auth::Challenge::Password;
use Koha::Database;

use lib File::Basename::dirname($INC{"Koha/Borrowers.pm"})."/../C4/SIP";
use ILS::Patron;

sub list_borrowers {
    my ($c, $args, $cb) = @_;
    try {
        my $resultset = Koha::Database->new()->schema()->resultset('Borrower');
        my @bor = $resultset->search({'-or' => $args},{rows => 20});
        @bor = map {Koha::Borrower::swaggerize(  Koha::Borrowers->_wrap($_)  )} @bor;

        $c->$cb(\@bor, 200);
    } catch {
        return $c->$cb({
            error => "$_"
        }, 500);
    };
}

sub get_borrower {
    my ($c, $args, $cb) = @_;

    try {
        my $borrower = Koha::Borrowers->find($args->{borrowernumber});

        if ($borrower) {
            return $c->$cb($borrower->swaggerize, 200);
        }

        $c->$cb({error => "Borrower not found"}, 404);
    } catch {
        return $c->$cb({
            error => "$_"
        }, 500);
    };
}

sub status {
    my ($c, $args, $cb) = @_;

    my ($borrower, $error);
    try {
        $borrower = Koha::Auth::Challenge::Password::challenge($args->{uname}, $args->{passwd});
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::LoginFailed')) {
            $error = $_;
        }
        else {
            return $c->$cb({
                error => "$_"
            }, 500);
        }
    };
    return $c->$cb({error => $error->error}, 400) if $error;

    my $ilsBorrower = ILS::Patron->new($borrower->userid);

    my $payload = { borrowernumber => 0 + $borrower->borrowernumber,
                    cardnumber     => $borrower->cardnumber || '',
                    surname        => $borrower->surname || '',
                    firstname      => $borrower->firstname || '',
                    homebranch     => $borrower->branchcode || '',
                    fines          => ($ilsBorrower->fines_amount) ? 0 + $ilsBorrower->fines_amount : 0,
                    language       => 'fin' || '',
                    charge_privileges_denied => ($ilsBorrower->charge_ok)      ? Mojo::JSON->false : Mojo::JSON->true,
                    renewal_privileges_denied => ($ilsBorrower->renew_ok)      ? Mojo::JSON->false : Mojo::JSON->true,
                    recall_privileges_denied => ($ilsBorrower->recall_ok)      ? Mojo::JSON->false : Mojo::JSON->true,
                    hold_privileges_denied =>     ($ilsBorrower->hold_ok)      ? Mojo::JSON->false : Mojo::JSON->true,
                    card_reported_lost =>       ($ilsBorrower->card_lost)      ? Mojo::JSON->true : Mojo::JSON->false,
                    too_many_items_charged => ($ilsBorrower->too_many_charged) ? Mojo::JSON->true : Mojo::JSON->false,
                    too_many_items_overdue => ($ilsBorrower->too_many_overdue) ? Mojo::JSON->true : Mojo::JSON->false,
                    too_many_renewals => ($ilsBorrower->too_many_renewal)      ? Mojo::JSON->true : Mojo::JSON->false,
                    too_many_claims_of_items_returned => ($ilsBorrower->too_many_claim_return) ? Mojo::JSON->true : Mojo::JSON->false,
                    too_many_items_lost =>  ($ilsBorrower->too_many_lost)      ? Mojo::JSON->true : Mojo::JSON->false,
                    excessive_outstanding_fines => ($ilsBorrower->excessive_fines) ? Mojo::JSON->true : Mojo::JSON->false,
                    excessive_outstanding_fees => ($ilsBorrower->excessive_fees) ? Mojo::JSON->true : Mojo::JSON->false,
                    recall_overdue => ($ilsBorrower->recall_overdue)           ? Mojo::JSON->true : Mojo::JSON->false,
                    too_many_items_billed => ($ilsBorrower->too_many_billed)   ? Mojo::JSON->true : Mojo::JSON->false,
                  };

    return $c->$cb($payload, 200);
}

sub get_self_service_status {
    my ($c, $args, $cb) = @_;

    try {
        my $borrower = Koha::Borrowers->cast($args->{cardnumber});

        my $ilsBorrower = ILS::Patron->new($borrower->userid);

        my $payload = {
            permission => ($ilsBorrower->card_lost ||
                           $ilsBorrower->expired ||
                           not($ilsBorrower->hold_ok) || #debarred
                           $ilsBorrower->excessive_fines ||
                           $ilsBorrower->excessive_fees)
                            ? Mojo::JSON->false : Mojo::JSON->true,
        };

        return $c->$cb($payload, 200);

    } catch {
        unless (blessed($_) && $_->can('rethrow')) {
            die $_;
        }
        if ($_->isa('Koha::Exception::UnknownObject')) {
            return $c->$cb({error => 'No such cardnumber'}, 404);
        }
        $_->rethrow();
    };
}

1;

