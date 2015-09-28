package Koha::Auth;

# Copyright 2015 Vaara-kirjastot
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

#Define common packages
use Modern::Perl;
use Scalar::Util qw(blessed);
use Try::Tiny;

#Define Koha packages
use Koha::Auth::RequestNormalizer;
use Koha::Auth::Route::Password;
use Koha::Auth::Route::Cookie;
use Koha::Auth::Route::RESTV1;

#Define Exceptions
use Koha::Exception::BadParameter;
use Koha::Exception::Logout;
use Koha::Exception::UnknownProgramState;

use C4::Branch;

#Define the headers, POST-parameters and cookies extracted from the various web-frameworks'
# request-objects and passed to the authentication system as normalized values.
our @authenticationHeaders = ('X-Koha-Date', 'Authorization');
our @authenticationPOSTparams = ('password', 'userid', 'PT', 'branch', 'logout.x', 'koha_login_context');
our @authenticationCookies = ('CGISESSID'); #Really we should have only one of these.

=head authenticate

@PARAM3 HASHRef of authentication directives. Supported values:
            'inOPAC' => 1,    #Authentication context is in OPAC
            'inREST' => 'v1', #Authentication context is in REST API V1
            'inSC'   => 1,    #Authentication context is in the staff client
            'authnotrequired' => 1, #Disregard all Koha::Exception::LoginFailed||NoPermission-exceptions,
                                    #and authenticate as an anonymous user if normal authentication
                                    #fails.
@THROWS Koha::Exception::VersionMismatch
        Koha::Exception::BadSystemPreference
        Koha::Exception::BadParameter
        Koha::Exception::ServiceTemporarilyUnavailable
        Koha::Exception::LoginFailed
        Koha::Exception::NoPermission
        Koha::Exception::Logout, catch this and redirect the request to the logout page.
=cut

sub authenticate {
    my ($controller, $permissions, $authParams) = @_;
    my $rae = _authenticate_validateAndNormalizeParameters(@_); #Get the normalized request authentication elements

    my $borrower; #Each authentication route returns a Koha::Borrower-object on success. We use this to generate the Context()

    ##Select the Authentication route.
    ##Routes are introduced in priority order, and if one matches, the other routes are ignored.
    try {
        #0. Logout
        if ($rae->{postParams}->{'logout.x'}) {
            clearUserEnvironment($rae, $authParams);
            Koha::Exception::Logout->throw(error => "User logged out. Please redirect me!");
        }
        #1. Check for password authentication, including LDAP.
        elsif ($rae->{postParams}->{koha_login_context} && $rae->{postParams}->{userid} && $rae->{postParams}->{password}) {
            $borrower = Koha::Auth::Route::Password::challenge($rae, $permissions, $authParams);
        }
        #2. Check for REST's signature-based authentication.
        #elsif ($rae->{headers}->{'Authorization'} && $rae->{headers}->{'Authorization'} =~ /Koha/) {
        elsif ($rae->{headers}->{'Authorization'}) {
            $borrower = Koha::Auth::Route::RESTV1::challenge($rae, $permissions, $authParams);
        }
        #3. Check for the cookie. If cookies go stale, they block all subsequent authentication methods, so keep it down on this list.
        elsif ($rae->{cookies}->{CGISESSID}) {
            $borrower = Koha::Auth::Route::Cookie::challenge($rae, $permissions, $authParams);
        }
        else { #HTTP CAS ticket or shibboleth or Persona not implemented
            #We don't know how to authenticate, or there is no authentication attempt.
            Koha::Exception::LoginFailed->throw(error => "Koha doesn't understand your authentication protocol.");
        }
    } catch {
        if (blessed($_)) {
            if ($_->isa('Koha::Exception::LoginFailed') || $_->isa('Koha::Exception::NoPermission')) {
                if ($authParams->{authnotrequired}) { #We failed to login, but we can continue anonymously.
                    $borrower = Koha::Borrower->new();
                }
                else {
                    $_->rethrow(); #Anonymous login not allowed this time
                }
            }
            else {
                die $_; #Propagate other errors to the calling Controller to redirect as it wants.
            }
        }
        else {
            die $_; #Not a Koha::Exception-object
        }
    };

    my $session = setUserEnvironment($controller, $rae, $borrower, $authParams);
    my $cookie = Koha::Auth::RequestNormalizer::getSessionCookie($controller, $session);

    return ($borrower, $cookie);
}

=head _authenticate_validateAndNormalizeParameters

@PARAM1 CGI- or Mojolicious::Controller-object, this is used to identify which web framework to use.
@PARAM2 HASHRef or undef, Permissions HASH telling which Koha permissions the user must have, to access the resource.
@PARAM3 HASHRef or undef, Special authentication parameters, see authenticate()
@THROWS Koha::Exception::BadParameter, if validating parameters fails.
=cut

sub _authenticate_validateAndNormalizeParameters {
    my ($controller, $permissions, $authParams) = @_;

    #Validate $controller.
    my $requestAuthElements;
    if (blessed($controller) && $controller->isa('CGI')) {
        $requestAuthElements = Koha::Auth::RequestNormalizer::normalizeCGI($controller, \@authenticationHeaders, \@authenticationPOSTparams, \@authenticationCookies);
    }
    elsif (blessed($controller) && $controller->isa('Mojolicious::Controller')) {
        $requestAuthElements = Koha::Auth::RequestNormalizer::normalizeMojolicious($controller, \@authenticationHeaders, \@authenticationPOSTparams, \@authenticationCookies);
    }
    else {
        Koha::Exception::BadParameter->throw(error => "Koha::Auth::authenticate():> The first parameter MUST be either a 'CGI'-object or a 'Mojolicious::Controller'-object");
    }
    #Validate $permissions
    unless (not($permissions) || (ref $permissions eq 'HASH')) {
        Koha::Exception::BadParameter->throw(error => "Koha::Auth::authenticate():> The second parameter MUST be 'undef' or a HASHRef of Koha permissions. See C4::Auth::haspermission().");
    }
    #Validate $authParams
    unless (not($authParams) || (ref $authParams eq 'HASH')) {
        Koha::Exception::BadParameter->throw(error => "Koha::Auth::authenticate():> The third parameter MUST be 'undef' or a HASHRef.");
    }

    return $requestAuthElements;
}

=head setUserEnvironment
Set the C4::Context::user_env() and CGI::Session.

Any idea why there is both the CGI::Session and C4::Context::usernenv??
=cut

sub setUserEnvironment {
    my ($controller, $rae, $borrower, $authParams) = @_;

    my $session = C4::Auth::get_session( $rae->{cookies}->{CGISESSID} || '' );
    C4::Context->_new_userenv( $session->id );

    _determineUserBranch($rae, $borrower, $authParams, $session);

    #Then start setting remaining session parameters
    $session->param( 'number',       $borrower->borrowernumber );
    $session->param( 'id',           $borrower->userid );
    $session->param( 'cardnumber',   $borrower->cardnumber );
    $session->param( 'firstname',    $borrower->firstname );
    $session->param( 'surname',      $borrower->surname );
    $session->param( 'emailaddress', $borrower->email );
    $session->param( 'ip',           $session->remote_addr() );
    $session->param( 'lasttime',     time() );

    #Finally configure the userenv.
    C4::Context->set_userenv(
        $session->param('number'),       $session->param('id'),
        $session->param('cardnumber'),   $session->param('firstname'),
        $session->param('surname'),      $session->param('branch'),
        $session->param('branchname'),   undef,
        $session->param('emailaddress'), $session->param('branchprinter'),
        $session->param('persona'),      $session->param('shibboleth')
    );

    return $session;
}

sub _determineUserBranch {
    my ($rae, $borrower, $authParams, $session) = @_;

    my ($branchcode, $branchname);
    if ($rae->{postParams}->{branch}) {
        #We are instructed to change the active branch
        $branchcode = $rae->{postParams}->{branch};
    }
    elsif ($session->param('branch') && $session->param('branch') ne 'NO_LIBRARY_SET') {
        ##Branch is already set
        $branchcode = $session->param('branch');
    }
    elsif ($borrower->branchcode) {
        #Default to the borrower's branch
        $branchcode = $borrower->branchcode;
    }
    else {
        #No borrower branch? This must be the superuser.
        $branchcode = 'NO_LIBRARY_SET';
        $branchname = 'NO_LIBRARY_SET';
    }
    $session->param( 'branch',     $branchcode );
    $session->param( 'branchname', ($branchname || C4::Branch::GetBranchName($branchcode) || 'NO_LIBRARY_SET'));
}

=head clearUserEnvironment

Removes all active authentications
=cut

sub clearUserEnvironment {
    my ($rae, $authParams) = @_;

    my $session = C4::Auth::get_session( $rae->{cookies}->{CGISESSID} );
    $session->delete();
    $session->flush;
    #Do we need to unset this if it has never been set? C4::Context::_unset_userenv( $rae->{cookies}->{CGISESSID} );
}
1;