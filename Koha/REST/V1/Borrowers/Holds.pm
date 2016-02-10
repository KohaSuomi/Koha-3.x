package Koha::REST::V1::Borrowers::Holds;

use Modern::Perl;
use Try::Tiny;
use Scalar::Util qw(blessed);

use Mojo::Base 'Mojolicious::Controller';

use Koha::Borrowers;
use Koha::Borrower;

use C4::Biblio;
use C4::Dates;
use C4::Reserves;

sub list_borrower_holds {
    my ($c, $args, $cb) = @_;

    my $borrowernumber = $args->{borrowernumber};
    my $borrower = Koha::Borrowers->find($borrowernumber);
    unless ($borrower) {
        return $c->$cb({error => "Borrower not found"}, 404);
    }

    my @holds = map {C4::Reserves::swaggerizeHold($_)} C4::Reserves::GetReservesFromBorrowernumber($borrowernumber);

    unless (scalar(@holds)) {
        return $c->$cb({error => "Borrower has no Holds"}, 404);
    }
    return $c->$cb(\@holds, 200);
}

sub add_borrower_hold {
    my ($c, $args, $cb) = @_;

    my $body = $c->req->json;
    $body->{borrowernumber} = $args->{borrowernumber};

    try {
        my $hold = C4::Reserves::swaggerizeHold( C4::Reserves::PlaceHold($body) );
        return $c->$cb($hold, 201);
    } catch {
        if (blessed($_)) {
            if ($_->isa('Koha::Exception::BadParameter')) {
                return $c->$cb({
                    error => $_->error()
                }, 400);
            }
            elsif ($_->isa('Koha::Exception::NoPermission')) {
                return $c->$cb({
                    error => $_->error()
                }, 403);
            }
            elsif ($_->isa('Koha::Exception::UnknownObject')) {
                return $c->$cb({
                    error => $_->error()
                }, 404);
            }
            elsif ($_->isa('Koha::Exception::DB')) {
                return $c->$cb({
                    error => $_->error()
                }, 500);
            }
        }
        return $c->$cb({
            error => "$_"
        }, 500);
    };
}

1;
