package t::lib::RESTTest;

use Modern::Perl;
use Test::More;

use Class::Accessor "antlers";
__PACKAGE__->follow_best_practice();

has testImplementationMainPackage => (is => 'rw', isa => 'Str'); #eg. 't::db_dependent::api'
has basePath        => (is => 'rw', isa => 'Str'); #eg. '/v1'
has pathsObjectPath => (is => 'rw', isa => 'Str'); #eg. '/borrowers/{borrowernumber}/issues/{itemnumber}'
has httpVerb        => (is => 'rw', isa => 'Str'); #eg. 'get'
has httpStatusCode  => (is => 'rw', isa => 'Str'); #eg. '404'
has packageName     => (is => 'rw', isa => 'Str'); #eg. 'Borrowers'
has subroutineName  => (is => 'rw', isa => 'Str'); #eg. 'get_n_200'
has swagger2specification => (is => 'rw', isa => 'HASH'); #The Swagger2 specification as HASH
has operationObject => (is => 'rw', isa => 'HASH'); #The Swagger2 specifications OperationObject this test tests.
has activeBorrower  => (is => 'rw', isa => 'Koha::Borrower'); #The Borrower who is consuming the REST API, and doing the authentication.
has apiKey          => (is => 'rw', isa => 'Str'); #eg."23f08sev90-42vfwv+ave3v==Ac", active borrower's api key
has testContext     => (is => 'rw', isa => 'HASH'); #Test context for this test case, used to collect all DB modifications in one place for easy removal.

use Koha::Exception::BadParameter;

=head new

    t::lib::RESTTest->new({
            testImplementationMainPackage => 't::db_dependent::api',
            basePath => '/v1',
            pathsObj_Path => '/borrowers/{borrowernumber}/issues/{itemnumber}',
            httpVerb => 'get',
            httpStatusCode => '200',
            specification => $specification,
            operationObject => $operationObject,
            activeBorrower => $activeBorrower,
            apiKey => "23f08sev90-42vfwv+ave3v==Ac", #Active borrowers api key
    });

=cut

sub new {
    my ($class, $params) = @_;

    bless($params, $class);
    _validateParams($params);

    $params->set_testContext({});

    #We need to create the package and subroutine path to dynamically check that test-subroutines are defined for the specified paths.
    $params->_buildPackageAndSubroutineName();
    return $params;
}

=head _validateParams

@THROWS Koha::Exception::BadParameter, if validation fails.
=cut

sub _validateParams {
    my ($params) = @_;

    ##Actually check the params
    unless ($params->{testImplementationMainPackage}) {
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> no 'testImplementationMainPackage'-parameter given! It must be the root package from where to look for test implementations, eg. 't::db_dependent'");
    }
    unless ($params->{basePath}) {
        $params->{basePath} = '/api/v1';
    }

    if ($params->{pathsObjectPath}) {
        my ($sModule, $sPathTail) = ($1, $2) if $params->{pathsObjectPath} =~ /^\/(\w+)\/?(.*)$/;
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> Unable to parse the module name from '".$params->{pathsObjectPath}."'. Please fix the module parser!")
                    unless $sModule;
    }
    else {
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> no 'pathsObjectPath'-parameter given!");
    }

    unless ($params->{httpVerb}) {
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> no 'httpVerb'-parameter given!");
    }

    unless ($params->{httpStatusCode}) {
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> no 'httpStatusCode'-parameter given!");
    }

    unless ($params->{swagger2specification}) {
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> no 'swagger2specification'-parameter given!");
    }

    unless ($params->{operationObject}) {
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> no 'operationObject'-parameter given!");
    }

    unless ($params->{activeBorrower}) {
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> no 'activeBorrower'-parameter given!");
    }

    unless ($params->{apiKey}) {
        Koha::Exception::BadParameter->throw(error => "RESTTest->new():> no 'apiKey'-parameter given!");
    }
}

sub _buildPackageAndSubroutineName {
    my ($self) = @_;

    my $bp = $self->get_basePath();
    my @bp = split('/', $bp);
    shift(@bp);
    $bp = join('::', map {ucfirst($_)} @bp );

    my ($sModule, $sPathTail) = ($1, $2) if $self->get_pathsObjectPath() =~ /^\/(\w+)\/?(.*)$/;
    $sPathTail =~ s/\{.*?\}/_n_/g;
    $sPathTail =~ s/\///g;

    my $testPackageName = join('::',$self->get_testImplementationMainPackage, $bp, ucfirst($sModule));
    $self->set_packageName($testPackageName);

    my $testSubroutineName = $self->get_httpVerb(). #eg. get
                             (($sPathTail) ? $sPathTail : ''). #eg. borrowers_n_
                             $self->get_httpStatusCode(); #eg. 200, 404, 403, ...
    $self->set_subroutineName($testSubroutineName);
}

=head get_routePath

    my $path = $restTest->get_routePath({borrowernumber => 911,
                                         itemnumber => 112});

Returns the full path to make a request to. Optionally substitutes path parameters.
@PARAM1 HASHRef, {pathparameter => value, ...} substitutes pathparameters with values
        or SCALAR, <pathparameter>, substitutes all pathparameters with this value

=cut

sub get_routePath {
    my ($self, $substitutions) = @_;
    my $path = $self->get_basePath().$self->get_pathsObjectPath();

    sub __substitute {
        my ($path, $k, $v, $global) = @_;
        if ($global) {
            $path =~ s!{$k?}!$v!g;
        }
        else {
            $path =~ s!{$k?}!$v!;
        }
        return $path;
    }

    if (ref($substitutions) eq 'HASH') {
        while (my ($k,$v) = each(%$substitutions)) {
            $path = __substitute($path, $k, $v, 'g');
        }
    }
    elsif (ref($substitutions) eq 'ARRAY') {
        foreach my $substitution (@$substitutions) {
            $path = __substitute($path, '.+', $substitution, undef);
        }
    }
    elsif ($substitutions) {
        $path = __substitute($path, '.+', $substitutions);
    }

    return $path;
}
sub get_requiredPermissions {
    my ($self) = @_;
    return $self->get_operationObject()->{'x-koha-permission'};
}

sub catchSwagger2Errors {
    my ($self, $driver) = @_;
    #Check should we display warnings?
    if ($self->get_httpStatusCode =~ /^2\d\d$/) { #Any 2xx status codes should not have errors/warnings so display them always
        #proceed
    }
    elsif ($ENV{KOHA_REST_API_DEBUG} > 0) { #Any other status codes test for failure scenarios, and their correct behaviour is to fail so we don't spam unnecessarily
        #proceed if debug is activated
    }
    else {
        return 1; #No warnings
    }

    my ($json, $body, $res);
    $res = $driver->tx->res if $driver->isa('Test::Mojo');
    $res = $driver->res if $driver->isa('Mojo::Transaction');
    $json = $res->json;
    $body = $res->body unless $json;

    ###Try to figure out what kind of an error we have, if any
    if ($json && ref($json) eq 'HASH') {
        #These are from the Swagger2-subsystem and are always an ARRAY of HASHes
        if($json->{errors} && ref($json->{errors}) eq 'ARRAY' && ref($json->{errors}->[0]) eq 'HASH') {
            my @cc = caller(1);
            foreach my $err (@{$json->{errors}}) {
                warn $cc[3].'():> '.$err->{message}." AT path: '".$err->{path}."'\n";
            }
        }
        #These are thrown from the Mojolicous routes created by Swagger2, and should be text.
        elsif (my $error = $json->{error} || $json->{err}) {
            my @cc = caller(1);
            warn $cc[3]."():> $error\n";
        }
    }
    elsif ($body && $body =~ /^\Q<!DOCTYPE html>\E/) {
        use Mojo::DOM;
        my $dom = Mojo::DOM->new($body);
        my $error;
        if ($dom->at("#error")) {
            $error = $dom->at("#error")->text;
        }
        elsif ($dom->at("#wrapperlicious")) {
            $error =  $dom->at("#wrapperlicious")->to_string;
        }
        else {
            $error = 'BAD ERROR HANDLING IN '.__PACKAGE__.' HELP ME!';
        }
        my @cc = caller(1);
        warn $cc[3]."():> $error\n";
    }
}

1;
