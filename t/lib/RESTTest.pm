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

our $testImplementationMainPackage = 't::db_dependent';

sub new {
    my ($class, $params) = @_;

    bless($params, $class);
    _validateParams($params);

    $params->set_testImplementationMainPackage($testImplementationMainPackage) unless $params->get_testImplementationMainPackage();
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
    $bp =~ s!^/!!;
    my @bp = map {ucfirst($_)} split('/', $bp);
    $bp = join('::', @bp);

    my ($sModule, $sPathTail) = ($1, $2) if $self->get_pathsObjectPath() =~ /^\/(\w+)\/?(.*)$/;
    $sPathTail =~ s/\{.*?\}/_n_/g;
    $sPathTail =~ s/\///g;

    my $testPackageName = $testImplementationMainPackage.'::'. #typically t::db_dependent::api
                             ucfirst($bp).'::'. #version, v1
                             ucfirst($sModule); #borrowers, etc.
    $self->set_packageName($testPackageName);

    my $testSubroutineName = $self->get_httpVerb(). #eg. get
                             (($sPathTail) ? $sPathTail : ''). #eg. borrowers_n_
                             $self->get_httpStatusCode(); #eg. 200, 404, 403, ...
    $self->set_subroutineName($testSubroutineName);
}

sub get_routePath {
    my $self = shift;
    return $self->get_basePath().$self->get_pathsObjectPath();
}
sub get_requiredPermissions {
    my ($self) = @_;
    return $self->get_operationObject()->{'x-koha-permission'};
}

1;
