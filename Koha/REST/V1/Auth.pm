package Koha::REST::V1::Auth;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Borrowers;
use C4::Auth;
use Data::Dumper;

# Checks whether the given sessionid is valid at the time. If a valid session is found,
# a minimal subset of borrower's info is returned for the SSO-scheme:
# $borrower = {
#   firstname => firstname,
#   lastname => surname,
#   email => email
# }
sub get_session {
    my ($c, $args, $cb) = @_;

    my $sessionId = $args->{session}->{sessionid};
    my $session = C4::Auth::get_session($sessionId);

    # If the returned session equals the given session, accept it as a valid session and return it.
    # Otherwise, destroy the created session.
    if ($sessionId eq $session->param('_SESSION_ID')) {
        my $borrower = Koha::Borrowers->find($session->param('number'));
        $borrower = $borrower->unblessed;
        if ($borrower) {
            my $response = {
                email => $borrower->{email},
                firstname => $borrower->{firstname},
                lastname => $borrower->{surname}
            };
            $c->$cb($response, 200);
        }
        else {
            $c->$cb({error => "Borrower not found"}, 404);
        }
    }
    else {
        $session->delete();
        $session->flush();
        $c->$cb({error => "Bad session id"}, 400);
    }
}
1;
