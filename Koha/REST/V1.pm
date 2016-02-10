package Koha::REST::V1;

use Modern::Perl;
use Mojo::Base 'Mojolicious';
use Mojo::Log;
use Data::Walk;
use Scalar::Util qw(blessed);
use Try::Tiny;

use Koha::Borrower;
use Koha::Borrowers;
use Koha::ApiKey;
use Koha::ApiKeys;
use Koha::Auth;


=head startup

Starts the Mojolicious application using whatever server is configured.

Use environmental values to control some aspects of Mojolicious:
This way we can have different settings for different servers running Mojolicious.

=head2 Configuration file

$ENV{MOJO_CONFIG} should be set in the system service (init) starting Mojolicious, eg:
export MOJO_CONFIG=/home/koha/kohaclone/api/v1/hypnotoad.conf

This configuration file read by the Mojolicious::Plugin::Config
http://mojolicio.us/perldoc/Mojolicious/Plugin/Config

If you don't want to use any config files, disable the alert notifications ny setting the
MOJO_CONFIG-environment variable to undef.

=head2 Logging

    #NOTE!!
    #There is a "feature" in Mojo::Server disabling STDOUT and STDERR, because such errors are not-suited-for-production?!?
    #This modification in Mojo::Server disables this and preserves the STD* handles for forked server threads
    #in Mojo::Server::daemonize(), comment out the following lines
    #
    #  # Close filehandles
    #  open STDOUT, '>/dev/null';
    #  open STDERR, '>&STDOUT';

Log to a filename configured in an environment variable $ENV{MOJO_LOGFILES} using loglevel $ENV{MOJO_LOGLEVEL}.
Actually you get 3 logfiles on $ENV{MOJO_LOGFILES}.
.log for Mojo::Log
.stdout for STDOUT
.stderr for STDERR

Defaults to STDERR and loglevel of 'error'
Examples:
export MOJO_LOGFILES=/home/koha/koha-dev/var/log/kohaapi.mojo
export MOJO_LOGLEVEL=debug

Logging is done by Mojo::Log
http://www.mojolicio.us/perldoc/Mojo/Log

If you want to get log output to STDOUT and STDERR normally, disable the alert notifications by setting the
MOJO_LOGFILES-environment variable to undef.

=cut

sub startup {
    my $self = shift;

    $self->setKohaParamLogging();
    $self->setKohaParamConfig();

    # Force charset=utf8 in Content-Type header for JSON responses
    $self->types->type(json => 'application/json; charset=utf8');

    $self->plugin(Swagger2 => {
        url => $self->home->rel_file("api/v1/swagger/swagger.min.json"),
    });
}

sub setKohaParamConfig {
    my $self = shift;
    #Enable the config-plugin. Loads the config file from $ENV{MOJO_CONFIG} by default.
    if ($ENV{MOJO_CONFIG}) {
        $self->plugin('Config');
    }
    elsif (exists($ENV{MOJO_CONFIG})) {
        #Don't complain.
    }
    else {
        print __PACKAGE__."::startup():> No config-file loaded. Define your config-file to the MOJO_CONFIG environmental variable. If you don't want to use a specific config-file, set the MOJO_CONFIG to undef.\n";
    }
}

sub setKohaParamLogging {
    my $self = shift;
    #Log to a filename with loglevel configured in environment variables
    if ($ENV{MOJO_LOGFILES}) {
        $self->app->log( Mojo::Log->new( path => $ENV{MOJO_LOGFILES}.'.log', level => ($ENV{MOJO_LOGLEVEL} || 'error') ) );
        open(STDOUT,'>>',$ENV{MOJO_LOGFILES}.'.stdout') or die __PACKAGE__."::startup():> Couldn't open the STDOUT logfile for appending.\n".$!;
        open(STDERR,'>>',$ENV{MOJO_LOGFILES}.'.stderr') or die __PACKAGE__."::startup():> Couldn't open the STDERR logfile for appending.\n".$!;
    }
    #Stop complaining about missing logging config
    if (exists($ENV{MOJO_LOGFILES})) {
        $self->app->log();
    }
    else {
        $self->app->log(); #Default to STDERR
        print __PACKAGE__."::startup():> No logfile given, defaulting to STDERR. Define your logfile and loglevel to the MOJO_LOGFILES and MOJO_LOGLEVEL environmental variables. If you want foreground logging, set the MOJO_LOGFILES as undef.\n";
    }
    #Define the API debugging level to prevent undef warnings
    $ENV{"KOHA_REST_API_DEBUG"} = 0 unless $ENV{"KOHA_REST_API_DEBUG"};
}

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

sub koha_authenticate {
    my ($next, $c, $opObj) = @_;
    my ($error, $data, $statusCode); #define return values

    try {

        my $authParams = {};
        $authParams->{authnotrequired} = 1 unless $opObj->{"x-koha-permission"};
        my ($borrower, $cookie) = Koha::Auth::authenticate($c, $opObj->{"x-koha-permission"}, $authParams);

    } catch {
      my $e = $_;
      if (blessed($e)) {
        my $swagger2DocumentationUrl = _findConfigurationParameterFromAnyConfigurationFile($c->app->config(), 'swagger2DocumentationUrl') || '';

        if ($e->isa('Koha::Exception::NoPermission') ||
            $e->isa('Koha::Exception::LoginFailed') ||
            $e->isa('Koha::Exception::UnknownObject')
           ) {
          $error = [{message => $e->error, path => $c->req->url->path_query},
                    {message => "See '$swagger2DocumentationUrl' for how to properly authenticate to Koha"},];
          $data = {header => {"WWW-Authenticate" => "Koha $swagger2DocumentationUrl"}};
          $statusCode = 401; #Throw Unauthorized with instructions on how to properly authorize.
        }
        elsif ($e->isa('Koha::Exception::BadParameter')) {
          $error = [{message => $e->error, path => $c->req->url->path_query}];
          $data = {};
          $statusCode = 400; #Throw a Bad Request
        }
        elsif ($e->isa('Koha::Exception::VersionMismatch') ||
               $e->isa('Koha::Exception::BadSystemPreference') ||
               $e->isa('Koha::Exception::ServiceTemporarilyUnavailable')
              ){
          $error = [{message => $e->error, path => $c->req->url->path_query}];
          $data = {};
          $statusCode = 503; #Throw Service Unavailable, but will be available later.
        }
        else {
          $e->rethrow();
        }
      }
      else {
        die $e;
      }
    };
    return $next->($c) unless ($error || $data || $statusCode);
    return $c->render_swagger(
        {errors => $error},
        $data,
        $statusCode,
    );
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

sub _findConfigurationParameterFromAnyConfigurationFile {
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

1;
