package Koha::REST::V1::Auth;

use Modern::Perl;
use Data::Dumper;
use Scalar::Util qw(blessed);
use Try::Tiny;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Borrowers;
use Koha::Auth;
use Koha::Auth::Challenge::Cookie;
use C4::Auth;

use Koha::Exception::UnknownObject;

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
    if ($sessionId eq $session->id()) {

        # See if the given session is timed out
        if (Koha::Auth::Challenge::Cookie::isSessionExpired($session)) {
            return $c->$cb({error => "Koha's session expired."}, 401);
        }

        my $borrower = Koha::Borrowers->find($session->param('number'));
        unless ($borrower) {
            return $c->$cb({error => "Borrower not found"}, 404);
        }

        return $c->$cb(_swaggerizeSession($session), 200);
    }
    else {
        $session->delete();
        $session->flush();
        return $c->$cb({error => "Bad session id"}, 404);
    }
}

sub login {
    my ($c, $args, $cb) = @_;

    try {
        $c->req->params->append('koha_login_context' => 'REST');
        my $session = _swaggerizeSessionFromBorrowerAndCookie( Koha::Auth::authenticate($c, undef, {}) );

        return $c->$cb($session, 201);
    } catch {
        if (blessed($_)) {
            if ($_->isa('Koha::Exception::LoginFailed')) {
                return $c->$cb({
                    error => $_->error()
                }, 400);
            }
        }
        return $c->$cb({
            error => "$_"
        }, 500);
    };
}

sub logout {
    my ($c, $args, $cb) = @_;

    try {
        my $sessionid = $args->{session}->{sessionid};
        my $session = C4::Auth::get_session( $sessionid );
        my $swagSession = _swaggerizeSession($session); #Swag it before we lose it.
        unless (blessed($session) && $session->isa('CGI::Session') && $session->param('cardnumber')) {
            Koha::Exception::UnknownObject->throw(error => "No such session");
        }

        #Logout the user
        Koha::Auth::clearUserEnvironment( $session, {} );

        return $c->$cb($swagSession, 200);
    } catch {
        if (blessed($_)) {
            if ($_->isa('Koha::Exception::UnknownObject')) {
                return $c->$cb({
                    error => $_->error()
                }, 404);
            }
        }
        return $c->$cb({
            error => "$_"
        }, 500);
    };
}

=head _swaggerizeSessionFromBorrowerAndCookie

    my $swag = _swaggerizeSessionFromBorrowerAndCookie($Koha::Borrower, $CGI::Cookie);

@RETURNS HASHRef, a Swagger2 session-object
=cut
sub _swaggerizeSessionFromBorrowerAndCookie {
    my ($borrower, $cookie) = @_;
    $borrower = Koha::Borrowers->cast($borrower);

    return {
        firstname => $borrower->firstname,
        lastname  => $borrower->surname,
        email     => $borrower->email,
        sessionid => $cookie->value(),
    };
}
=head _swaggerizeSession

    my $swag = _swaggerizeSession($CGI::Session);

@RETURNS HASHRef, a Swagger2 session-object
=cut
sub _swaggerizeSession {
    my ($session) = @_;

    return {
        firstname => $session->param('firstname'),
        lastname  => $session->param('surname'),
        email     => $session->param('emailaddress'),
        sessionid => $session->id,
    };
}

1;
