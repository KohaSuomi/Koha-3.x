package Koha::REST::V1::Plugins::KohaliciousSwagtenticator;

use Modern::Perl;

use base qw(Mojolicious::Plugin::Swagger2);

use Digest::SHA qw(hmac_sha256_hex);
use Try::Tiny;
use Scalar::Util qw(blessed);
use Data::Walk;

use Koha::Auth;

use Koha::Exception::BadAuthenticationToken;
use Koha::Exception::UnknownProgramState;
use Koha::Exception::NoPermission;

use constant DEBUG => $ENV{SWAGGER2_DEBUG} || 0;



################################################################################
######################  STARTING OVERLOADING SUBROUTINES  ######################
################################################################################



=head _generate_request_handler
@OVERLOADS Mojolicious::Plugin::Swagger2::_generate_request_handler()
This is just a copy-paste of the parent function with a small incision to inject the Koha-authentication mechanism.
Keep code changes minimal for upstream compatibility, so when problems arise, copy-pasting fixes them!

=cut

sub _generate_request_handler {
  my ($self, $method, $config) = @_;
  my $controller = $config->{'x-mojo-controller'} || $self->{controller};    # back compat

  return sub {
    my $c = shift;
    my $method_ref;

    unless (eval "require $controller;1") {
      $c->app->log->error($@);
      return $c->render_swagger($self->_not_implemented('Controller not implemented.'), {}, 501);
    }
    unless ($method_ref = $controller->can($method)) {
      $method_ref = $controller->can(sprintf '%s_%s', $method, lc $c->req->method)
        and warn "HTTP method name is not used in method name lookup anymore!";
    }
    unless ($method_ref) {
      $c->app->log->error(
        qq(Can't locate object method "$method" via package "$controller. (Something is wrong in @{[$self->url]})"));
      return $c->render_swagger($self->_not_implemented('Method not implemented.'), {}, 501);
    }
    #########################################
    ####### Koha-overload starts here #######
    ## Check for user api-key authentication and permissions.
    my ($error, $data, $statusCode) = _koha_authenticate($c, $config);
    return $c->render_swagger($error, $data, $statusCode) if $error;
    ### END OF Koha-overload              ###
    #########################################

    bless $c, $controller;    # ugly hack?

    $c->delay(
      sub {
        my ($delay) = @_;
        my ($v, $input) = $self->_validate_input($c, $config);

        return $c->render_swagger($v, {}, 400) unless $v->{valid};
        return $c->$method_ref($input, $delay->begin);
      },
      sub {
        my $delay  = shift;
        my $data   = shift;
        my $status = shift || 200;
        my $format = $config->{responses}{$status} || $config->{responses}{default} || {};
        my @err    = $self->_validator->validate($data, $format->{schema});

        return $c->render_swagger({errors => \@err, valid => Mojo::JSON->false}, $data, 500) if @err;
        return $c->render_swagger({}, $data, $status);
      },
    );
  };
}



################################################################################
#########  END OF OVERLOADED SUBROUTINES, STARTING EXTENDED FEATURES  ##########
################################################################################



=head _koha_authenticate

    _koha_authenticate($c, $config);

Checks all authentications in Koha, and prepares the data for a
Mojolicious::Plugin::Swagger2->render_swagger($errors, $data, $statusCode) -response
if authentication failed for some reason.

@PARAM1 Mojolicious::Controller or a subclass
@PARAM2 Reference to HASH, the "Operation Object" from Swagger2.0 specification,
                            matching the given "Path Item Object"'s HTTP Verb.
@RETURNS List of: HASH Ref, errors encountered
                  HASH Ref, data to be sent
                  String, status code from the Koha::REST::V1::check_key_auth()
=cut

sub _koha_authenticate {
    my ($c, $opObj) = @_;
    my ($error, $data, $statusCode); #define return values

    try {

        my $authParams = {};
        $authParams->{authnotrequired} = 1 unless $opObj->{"x-koha-permission"};
        Koha::Auth::authenticate($c, $opObj->{"x-koha-permission"}, $authParams);

    } catch {
      my $e = $_;
      if (blessed($e)) {
        my $swagger2DocumentationUrl = findConfigurationParameterFromAnyConfigurationFile($c->app->config(), 'swagger2DocumentationUrl') || '';

        if ($e->isa('Koha::Exception::NoPermission') ||
            $e->isa('Koha::Exception::LoginFailed') ||
            $e->isa('Koha::Exception::UnknownObject')
           ) {
          $error = {valid => Mojo::JSON->false, errors => [{message => $e->error, path => $c->req->url->path_query},
                                                           {message => "See '$swagger2DocumentationUrl' for how to properly authenticate to Koha"},]};
          $data = {header => {"WWW-Authenticate" => "Koha $swagger2DocumentationUrl"}};
          $statusCode = 401; #Throw Unauthorized with instructions on how to properly authorize.
        }
        elsif ($e->isa('Koha::Exception::BadParameter')) {
          $error = {valid => Mojo::JSON->false, errors => [{message => $e->error, path => $c->req->url->path_query}]};
          $data = {};
          $statusCode = 400; #Throw a Bad Request
        }
        elsif ($e->isa('Koha::Exception::VersionMismatch') ||
               $e->isa('Koha::Exception::BadSystemPreference') ||
               $e->isa('Koha::Exception::ServiceTemporarilyUnavailable')
              ){
          $error = {valid => Mojo::JSON->false, errors => [{message => $e->error, path => $c->req->url->path_query}]};
          $data = {};
          $statusCode = 503; #Throw Service Unavailable, but will be available later.
        }
        else {
          die $e;
        }
      }
      else {
        die $e;
      }
    };
    return ($error, $data, $statusCode);
}

=head findConfigurationParameterFromAnyConfigurationFile

Because we can use this REST API with CGI, or Plack, or Hypnotoad, or Morbo, ...
We cannot know which configuration file we are currently using.
$conf = {hypnotoad => {#conf params},
         plack     => {#conf params},
         ...
        }
So find the needed markers from any configuration file.
=cut

sub findConfigurationParameterFromAnyConfigurationFile {
  my ($conf, $paramLookingFor) = @_;

  my $found;
  my $wanted = sub {
    if ($_ eq $paramLookingFor) {
      $found = $Data::Walk::container->{$_};
      return ();
    }
  };
  Data::Walk::walk( $wanted, $conf);
  return $found;
}

return 1;