package Koha::REST::V1;

use Modern::Perl;
use Mojo::Base 'Mojolicious';
use Mojo::Log;

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

    my $route = $self->routes->under->to(
        cb => sub {
            my $c = shift;
            my $user = $c->param('user');
            # Do the authentication stuff here...
            $c->stash('user', $user);
            return 1;
        }
    );

    # Force charset=utf8 in Content-Type header for JSON responses
    $self->types->type(json => 'application/json; charset=utf8');

    $self->plugin(Swagger2 => {
        route => $route,
        url => $self->home->rel_file("api/v1/swagger.json"),
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
}
1;
