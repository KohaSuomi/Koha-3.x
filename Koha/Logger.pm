package Koha::Logger;

# Copyright 2015 ByWater Solutions
# kyle@bywatersolutions.com
# Copyright 2016 Koha-Suomi Oy
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

=head1 NAME

Koha::Log

=head1 SYNOPSIS

  use Koha::Log;

=head1 FUNCTIONS

=cut

use Modern::Perl;

use Log::Log4perl;
use Carp;
use Scalar::Util qw(blessed);
use Data::Dumper;

use C4::Context;

BEGIN {
    Log::Log4perl->wrapper_register(__PACKAGE__);
    $ENV{"LOG4PERL_CONF"} = C4::Context->config("log4perl_conf"); #Supercharge Koha::Log to skip unnecessary configuration file checking on each log attempt
    warn "\$KOHA_CONF/yazgfs/log4perl_conf is undefined. This must point to the Log4perl configuration file which should be in /home/koha/koha-dev/etc/log4perl.conf" unless C4::Context->config("log4perl_conf");
}

=head2 new

    my $logger = Koha::Logger->new($params);

See get() for available $params.
Prepares the logger for lazyLoading if uncertain whether or not the environment is set.
This is meant to be used to instantiate package-level loggers.

=cut

sub new {
    my ($class, $params) = @_;
    my $self = {lazyLoad => $params}; #Mark self as lazy loadable
    bless $self, $class;
    return $self;
}

=head2 get

    Returns a logger object (based on log4perl).
    Category and interface hash parameter are optional.
    Normally, the category should follow the current package and the interface
    should be set correctly via C4::Context.

=cut

sub get {
    my ( $class, $params ) = @_;
    my $interface = $params ? ( $params->{interface} || C4::Context->interface ) : C4::Context->interface;
    my $category = $params ? ( $params->{category} || caller ) : caller;
    my $l4pcat = $interface . '.' . $category;

    my $init = _init();
    my $self = {};
    if ($init) {
        $self->{logger} = Log::Log4perl->get_logger($l4pcat);
        $self->{cat}    = $l4pcat;
        $self->{logs}   = $init if ref $init;
    }
    bless $self, $class;

    $self->_checkLoggerOverloads();

    return $self;
}

=head2 sql

    $logger->sql('debug', $sql, $params) if $logger->is_debug();

Log SQL-statements using a unified interface.
@param {String} Log level
@param {String} SQL-command
@param {ArrayRef} SQL prepared statement parameters
@returns whatever Log::Log4perl returns

=cut

sub sql {
    my ($self, $level, $sql, $params) = @_;
    return $self->$level("$sql -- @$params");
}

=head2 flatten

    my $string = $logger->flatten(@_);

Given a bunch of $@%, the subroutine flattens those objects to a single human-readable string.

@PARAMS Anything, concatenates parameters to one flat string

=cut

sub flatten {
    my $self = shift;
    die __PACKAGE__."->flatten() invoked improperly. Invoke it with \$logger->flatten(\@params)" unless ((blessed($self) && $self->isa(__PACKAGE__)) || ($self eq __PACKAGE__));
    $Data::Dumper::Indent = 0;
    $Data::Dumper::Terse = 1;
    $Data::Dumper::Quotekeys = 0;
    $Data::Dumper::Maxdepth = 2;
    $Data::Dumper::Sortkeys = 1;
    return Data::Dumper::Dumper(\@_);
}

=head1 INTERNALS

=head2 AUTOLOAD

    In order to prevent a crash when log4perl cannot write to Koha logfile,
    we check first before calling log4perl.
    If log4perl would add such a check, this would no longer be needed.

=cut

sub AUTOLOAD {
    my ( $self, $line ) = @_;
    my $method = $Koha::Logger::AUTOLOAD;
    $method =~ s/^Koha::Logger:://;

    if ($self->{lazyLoad}) { #We have created this logger to be lazy loadable
        $self = ref($self)->get( $self->{lazyLoad} ); #Lazy load me!
    }

    if ( !exists $self->{logger} ) {

        #do not use log4perl; no print to stderr
    }
    elsif ( !$self->_recheck_logfile ) {
        warn "Log file not writable for log4perl";
        warn "$method: $line" if $line;
    }
    elsif ( $self->{logger}->can($method) ) {    #use log4perl
        return $self->{logger}->$method($line);
    }
    else {                                       # we should not really get here
        warn "ERROR: Unsupported method $method";
    }
    return;
}

=head2 DESTROY

    Dummy destroy to prevent call to AUTOLOAD

=cut

sub DESTROY { }

=head2 _init, _check_conf and _recheck_logfile

=cut

sub _init {
    my $rv;
    if ( exists $ENV{"LOG4PERL_CONF"} and $ENV{'LOG4PERL_CONF'} and -s $ENV{"LOG4PERL_CONF"} ) {

        # Check for web server level configuration first
        # In this case we ASSUME that you correctly arranged logfile
        # permissions. If not, log4perl will crash on you.
        # We will not parse apache files here.
        Log::Log4perl->init_once( $ENV{"LOG4PERL_CONF"} );
    }
    elsif ( C4::Context->config("log4perl_conf") ) {

        # Now look in the koha conf file. We only check the permissions of
        # the default logfiles. For the rest, we again ASSUME that
        # you arranged file permissions.
        my $conf = C4::Context->config("log4perl_conf");
        if ( $rv = _check_conf($conf) ) {
            Log::Log4perl->init_once($conf);
            return $rv;
        }
        else {
            return 0;
        }
    }
    else {
        # This means that you do not use log4perl currently.
        # We will not be forcing it.
        return 0;
    }
    return 1;    # if we make it here, log4perl did not crash :)
}

sub _check_conf {    # check logfiles in log4perl config (at initialization)
    my $file = shift;
    return if !-r $file;
    open my $fh, '<', $file;
    my @lines = <$fh>;
    close $fh;
    my @logs;
    foreach my $l (@lines) {
        if ( $l =~ /(OPAC|INTRANET)\.filename\s*=\s*(.*)\s*$/i ) {

            # we only check the two default logfiles, skipping additional ones
            return if !-w $2;
            push @logs, $1 . ':' . $2;
        }
    }
    return if !@logs;    # we should find one
    return \@logs;
}

sub _recheck_logfile {    # recheck saved logfile when logging message
    my $self = shift;

    return 1 if !exists $self->{logs};    # remember? your own responsibility
    my $opac = $self->{cat} =~ /^OPAC/;
    my $log;
    foreach ( @{ $self->{logs} } ) {
        $log = $_ if $opac && /^OPAC:/ || !$opac && /^INTRANET:/;
        last if $log;
    }
    $log =~ s/^(OPAC|INTRANET)://;
    return -w $log;
}

=head2 setConsoleVerbosity

    Koha::Logger->setConsoleVerbosity($verbosity);

Sets all Koha::Loggers to use also the console for logging and adjusts their verbosity by the given verbosity.

=USAGE

Do deploy verbose mode in a commandline script, add the following code:

    use C4::Context;
    use Koha::Logger;
    C4::Context->setCommandlineEnvironment();
    Koha::Logger->setConsoleVerbosity( 1 || -3 || 'WARN' || ... );

=PARAMS

@param {String or Signed Integer} $verbosity,
                if $verbosity is 0, no adjustment is made,
                If $verbosity is > 1, log level is decremented by that many steps towards TRACE
                If $verbosity is < 0, log level is incremented by that many steps towards FATAL
                If $verbosity is one of log levels, log level is set to that level.
                If $verbosity is undef, clear all overrides.

=cut

sub setConsoleVerbosity {
    if ($_[0] eq __PACKAGE__ || blessed($_[0]) && $_[0]->isa('Koha::Logger') ) {
        shift(@_); #Compensate for erratic calling styles.
    }
    my ($verbosity) = @_;

    if (defined($verbosity)) { #Tell all Koha::Loggers to use a console logger as well
        unless ($verbosity =~ /^-?\d+$/ ||
                $verbosity =~ /^(?:FATAL|ERROR|WARN|INFO|DEBUG|TRACE)$/) {
            my @cc = caller(0);
            die $cc[3]."($verbosity):> \$verbosity must be a positive or negative digit, or a valid Log::Log4perl log level, eg. FATAL, ERROR, WARN, ...";
        }
        $ENV{LOG4PERL_TO_CONSOLE} = 1;

        $ENV{LOG4PERL_VERBOSITY_CHANGE} = $verbosity if defined($verbosity);
    }
    else {
        delete $ENV{LOG4PERL_TO_CONSOLE};
        delete $ENV{LOG4PERL_VERBOSITY_CHANGE};
    }
}

=head2 _checkLoggerOverloads

Checks if there are Environment variables that should overload configured behaviour

=cut

# Define a stdout appender. I wonder how can I load a PatternedLayout from log4perl.conf here?
my $commandlineScreen =  Log::Log4perl::Appender->new(
                             "Log::Log4perl::Appender::Screen",
                             name      => "commandlineScreen",
                             stderr    => 0);
my $commandlineLayout = Log::Log4perl::Layout::PatternLayout->new( #I want this to be defined in log4perl.conf instead :(
                   "%d %M{2}> %m %n");
$commandlineScreen->layout($commandlineLayout);

sub _checkLoggerOverloads {
    my ($self) = @_;
    return unless blessed($self->{logger}) && $self->{logger}->isa('Log::Log4perl::Logger');

    if ($ENV{LOG4PERL_TO_CONSOLE}) {
        $self->{logger}->add_appender($commandlineScreen);
    }
    if ($ENV{LOG4PERL_VERBOSITY_CHANGE}) {
        if ($ENV{LOG4PERL_VERBOSITY_CHANGE} =~ /^-?(\d)$/) {
            if ($ENV{LOG4PERL_VERBOSITY_CHANGE} > 0) {
                $self->{logger}->dec_level( $1 );
            }
            elsif ($ENV{LOG4PERL_VERBOSITY_CHANGE} < 0) {
                $self->{logger}->inc_level( $1 );
            }
        }
        else {
            $self->{logger}->level( $ENV{LOG4PERL_VERBOSITY_CHANGE} );
        }
    }
}

=head1 AUTHOR

Kyle M Hall, E<lt>kyle@bywatersolutions.comE<gt>
Marcel de Rooy, Rijksmuseum
Olli-Antti Kivilahti, E<lt>olli-antti.kivilahti@jns.fiE<gt>

=cut

1;

__END__
