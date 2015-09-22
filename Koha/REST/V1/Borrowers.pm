package Koha::REST::V1::Borrowers;

use Modern::Perl;
use Scalar::Util qw(blessed);
use Try::Tiny;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;

use ILS::Patron;
use Koha::Borrowers;
use Koha::Auth::Challenge::Password;

sub list_borrowers {
    my ($c, $args, $cb) = @_;

    my $borrowers = Koha::Borrowers->search;

    $c->$cb($borrowers->unblessed, 200);
}

sub get_borrower {
    my ($c, $args, $cb) = @_;

    my $borrower = Koha::Borrowers->find($args->{borrowernumber});

    if ($borrower) {
        return $c->$cb($borrower->unblessed, 200);
    }

    $c->$cb({error => "Borrower not found"}, 404);
}

sub status {
    my ($c, $args, $cb) = @_;

    my ($borrower, $error);
    try {
        $borrower = Koha::Auth::Challenge::Password::challenge($args->{uname}, $args->{passwd});
    } catch {
        if (blessed($_)){
            if ($_->isa('Koha::Exception::LoginFailed')) {
                $error = $_;
            }
            else {
                $_->rethrow();
            }
        }
        else {
            die $_;
        }
    };
    return $c->$cb({error => $error->error}, 400) if $error;

    my $ilsBorrower = ILS::Patron->new($borrower->userid);

    my $payload = { borrowernumber => $borrower->borrowernumber,
                    cardnumber     => $borrower->cardnumber || '',
                    surname        => $borrower->surname || '',
                    firstname      => $borrower->firstname || '',
                    homebranch     => $borrower->branchcode || '',
                    fines          => 0 + $ilsBorrower->fines_amount || 0,
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

1;

