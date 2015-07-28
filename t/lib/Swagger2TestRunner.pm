package t::lib::Swagger2TestRunner;

use Modern::Perl;
use Test::More;

use Swagger2;
use YAML::XS;
use String::Random;

use C4::Context;

use Koha::ApiKeys;
use Koha::Auth::PermissionManager;
use Koha::Auth::Permissions;
use Koha::Auth::Challenge::RESTV1;

use t::lib::WebDriverFactory;
use t::lib::RESTTest;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::ObjectFactory;

use Koha::Exception::FeatureUnavailable;

=head new

    my $swagger2TestRunner = t::lib::Swagger2TestRunner->new({
                                                            testKeywords => ['borrowers','^issues', '@/borrowers/{borrowernumber}'],
    });

Gets the testrunner for you to operate on the REST API tests.
@PARAM1 HASHRef of parameters: {
            #Every route in the Swagger2 interface definition is matched against these
            #given keywords. Matching routes are targeted for operations.
            #    Keywords starting with ^ are negated, so they must not match
            #    Keywords starting with @ are complete matches, so they must match the url endpoint completely. A bit like a tag.
            #    Keywords with no special starting character must be found from the endpoint/url.
            #The special starting character is removed before matching.
            testKeywords => ['borrowers','^issues', '@/borrowers/{borrowernumber}'],
        }
=cut

sub new {
    my ($class, $params) = @_;

    my $self = $params || {};
    bless($self, $class);

    my $swagger = Swagger2->new->load( _getSwagger2Syspref() )->expand;
    $self->{swagger} = $swagger;
    $self->{testContext} = {}; #Collect all objects created for testing here for easy test context tearDown.

    return $self;
}

=head testREST
Gets and runs all the tests for all endpoints.
=cut

sub testREST {
    my ($self) = @_;
    my $tests = $self->getTests();
    $self->runTests($tests);
}

=head getTests
Reads through the Swagger2 API definition and prepares tests for each
returned HTTP status code within
each accepted HTTP verb within
each defined API endpoint/url

This enforces that no documented case is left untested.
If the 'testKeywords'-parameter is given during object instantiation, filters endpoints
with the keywords.
@RETURNS ARRAYRef of RESTTest-objects.
@THROW Koha::Exception::FeatureUnavailable, if Swagger2 is misconfigured or missing.
=cut

sub getTests {
    my ($self) = @_;

    my $tests = [];
    my $specification = $self->{swagger}->{tree}->{data};
    my $pathsObject = $specification->{paths};
    my $basePath = $specification->{basePath};

    my $activeBorrower = _getTestBorrower($self->{testContext}); #The Borrower who authenticates for the tests
    my $apiKey = Koha::ApiKeys->grant($activeBorrower);

    #Find the response object which encompasses all documented permutations of API calls.
    foreach my $pathsObject_path (grep {$_ if $_ !~ /^x-/i } sort keys(%$pathsObject)) { #Pick only Path Item Objects
        next unless _testPathsObject_pathAgainstTestKeywords($pathsObject_path, $self->{testKeywords});

        my $pathItemObject = $pathsObject->{$pathsObject_path};
        foreach my $httpVerb (grep {$_ if $_ =~ /(get|put|post|delete|options|head|patch)/i} sort keys(%$pathItemObject)) { #Pick only Operation Objects
            my $operationObject = $pathItemObject->{$httpVerb};
            foreach my $httpStatusCode (grep {$_ if $_ !~ /^x-/i } sort keys(%{$operationObject->{responses}})) { #Pick only Response Objects from the Responses Object.
                my $responseObject = $operationObject->{responses}->{$httpStatusCode};

                my $subtest = t::lib::RESTTest->new({basePath => $basePath,
                                                     pathsObjectPath => $pathsObject_path,
                                                     httpVerb => $httpVerb,
                                                     httpStatusCode => $httpStatusCode,
                                                     swagger2specification => $specification,
                                                     operationObject => $operationObject,
                                                     activeBorrower => $activeBorrower,
                                                     apiKey => $apiKey,
                                                     });
                push @$tests, $subtest;
            }
        }
    }
    @$tests = reverse @$tests;
    return $tests;
}

=head runTests
Executes the prepared tests.
Sets up the necessary authentication prerequisites documented in the Swagger2 API definition
prior to executing the test subroutine.
Tears down any preconfigured changes after each test.
=cut

sub runTests {
    my ($self, $tests) = @_;

    print "testREST():> Starting testing >>>\n";
    my ($driver) = t::lib::WebDriverFactory::getUserAgentDrivers('mojolicious');
    foreach my $subtest (@$tests) {
        my $testPackageName = $subtest->get_packageName();
        my $testSubroutineName = $subtest->get_subroutineName();
        eval "require $testPackageName";
        if ($@) {
            warn "$@\n";
        }

        if ($@) { #Trigger this test to fail if the package is unimplemented
            ok(0, "No test package defined for API route '".$subtest->get_routePath()."'. You must define it in $testPackageName->$testSubroutineName().");
        }
        elsif (not("$testPackageName"->can("$testSubroutineName"))) {
            ok(0, "No test subroutine defined for API route '".$subtest->get_routePath()."'. You must define it in $testPackageName->$testSubroutineName().");
        }
        else {
            $self->_prepareTestContext( $subtest, $driver );

            eval { #Prevent propagation of death from above, so we can continue testing and clean up the test context afterwards.
                no strict 'refs';
                subtest "$testPackageName->$testSubroutineName()" => sub {
                    "$testPackageName"->$testSubroutineName( $subtest, $driver );
                };
            };
            if ($@) {
                warn "$@\n";
            }

            $self->_tearDownTestContext( $subtest, $driver );
        }
    }
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($self->{testContext}); #Clear the global REST test context.
    done_testing;
}

sub _getSwagger2Syspref {
    my $swagger2DefinitionLocation = $ENV{KOHA_PATH}.'/api/v1/swagger.json';
    unless (-f $swagger2DefinitionLocation) {
        Koha::Exception::FeatureUnavailable->throw(error => "Swagger2TestRunner():> Couldn't find the Swagger2 definitions file from '$swagger2DefinitionLocation'. You must have a swagger.json-file to use the test runner.");
    }
    return $swagger2DefinitionLocation;
}

=head _getTestBorrower
Gets the universal active test Borrower used in all REST tests as the Borrower consuming the API.
=cut

sub _getTestBorrower {
    my ($testContext) = @_;
    my $borrowerFactory = t::lib::TestObjects::BorrowerFactory->new();
    my $borrowers = $borrowerFactory->createTestGroup([
            {firstname  => 'TestRunner',
             surname    => 'AI',
             cardnumber => '11A000',
             branchcode => 'CPL',
             address    => 'Technological Singularity',
             city       => 'Gehenna',
             zipcode    => '80140',
             email      => 'bionicman@example.com',
             categorycode => 'PT',
             dateofbirth => DateTime->now(time_zone => C4::Context->tz())->subtract(years => 21)->iso8601(), #I am always 21!
            },
        ], undef, $testContext);
    return $borrowers->{'11A000'};
}

=head _testPathsObject_pathAgainstTestKeywords
Implements the 'testKeywords'-parameter introduced in the constructor '->new()'.
=cut

sub _testPathsObject_pathAgainstTestKeywords {
    my ($pathsObject_path, $keywords) = @_;
    return 1 unless $keywords;
    foreach my $kw (@$keywords) {
        my ($exclude, $include, $only);
        if ($kw =~ /^\^(.+?)$/) {
            $exclude = $1;
        }
        elsif ($kw =~ /^\@(.+?)$/) {
            $only = $1;
        }
        else {
            $include = $kw;
        }

        if ($include) {
            return undef unless $pathsObject_path =~ m/\Q$include/;
        }
        elsif ($exclude) {
            return undef if $pathsObject_path =~ m/\Q$exclude/;
        }
        elsif ($only) {
            return undef unless $pathsObject_path =~ m/^\Q$only\E$/;
        }
    }
    return 1;
}

=head _prepareTestContext
Help to make implementing these tests maximally easy.
Make sure the active test Borrower has proper permissions to access the resource
 and the authentication headers are properly set.
=cut

sub _prepareTestContext {
    my ($self, $subtest, $driver) = @_;
    my $permissionsRequired = _replaceAnyPermissions( $subtest->get_requiredPermissions() );

    my $permissionManager = Koha::Auth::PermissionManager->new();
    $permissionManager->grantPermissions($subtest->get_activeBorrower(), $permissionsRequired);

    #Prepare authentication headers
    $driver->ua->once(start => sub { #Subscribe only once to this event, we need fresh headers on every HTTP request.
        my ($ua, $tx) = @_;
        my $headers = Koha::Auth::Challenge::RESTV1::prepareAuthenticationHeaders($subtest->get_activeBorrower(), undef, $subtest->get_httpVerb());
        $tx->req->headers->add('X-Koha-Date' => $headers->{'X-Koha-Date'});
        $tx->req->headers->add('Authorization' => $headers->{Authorization});
    });
}

=head _tearDownTestContext
Help to make implementing these tests maximally easy.
Remove all granted permissions so they wont interfere with other REST tests.

Also purges the test context created during test execution, if the context has been populated with TestObjectFactories.
=cut

sub _tearDownTestContext {
    my ($self, $subtest, $driver) = @_;
    my $testContext = $subtest->get_testContext();

    my $permissionManager = Koha::Auth::PermissionManager->new();
    $permissionManager->revokeAllPermissions($subtest->{activeBorrower});

    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);

    sleep 1; #Wait for Test::Mojo to clean up and reattach event handlers in it's asynchronous internals.
}

=head _replaceAnyPermission
When fulfilling the *-permission, we need to find any permission under the given
permissionmodule to satisfy the permission requirement.
=cut

sub _replaceAnyPermissions {
    my ($permissionsRequired) = @_;
    foreach my $module (keys %$permissionsRequired) {
        if ( $permissionsRequired->{$module} eq '*' ) {
            my @permissions = Koha::Auth::Permissions->search({module => $module});
            $permissionsRequired->{$module} = $permissions[0]->code;
        }
    }
    return $permissionsRequired;
}

1;
