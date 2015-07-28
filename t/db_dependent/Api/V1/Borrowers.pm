package t::db_dependent::Api::V1::Borrowers;

use Modern::Perl;
use Test::More;

use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::ObjectFactory;

#GET /borrowers/{borrowernumber}, with response 200

sub get_n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    #Create the test borrower.
    my $b = [{ cardnumber => '11A01', firstname => 'Olli', surname => 'Kiivi', password => '1234', userid => 'admin', branchcode => 'CPL' }];
    my $borrowers = t::lib::TestObjects::BorrowerFactory->createTestGroup($b, undef, $testContext, undef, undef);
    $b = $borrowers->{'11A01'};
    my $borrowernumber = $b->borrowernumber;

    #Execute request
    my $path = $restTest->get_routePath();
    $path =~ s/\{borrowernumber\}/$borrowernumber/;
    $driver->get_ok($path => {Accept => 'text/json'});
    $driver->status_is(200);

    #Compare result
    $driver->json_is('/borrowernumber' => $borrowernumber, "Got the same borrower '$borrowernumber'");
    my $json = $driver->tx->res->json();
    my $body = $driver->tx->res->body();

    return 1;
}

sub get_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    #Create the test borrower and get the borrowernumber. We know for sure that this borrowernumber is not already in use.
    my $b = [{ cardnumber => '11A01', firstname => 'Olli', surname => 'Kiivi', password => '1234', userid => 'admin', branchcode => 'CPL' }];
    my $borrowers = t::lib::TestObjects::BorrowerFactory->createTestGroup($b, undef, $testContext, undef, undef);
    $b = $borrowers->{'11A01'};
    my $borrowernumber = $b->borrowernumber;

    #Delete the borrower so we can no longer find it.
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);

    #Make the HTTP request
    my $path = $restTest->get_routePath();
    $path =~ s/\{borrowernumber\}/$borrowernumber/;
    $driver->get_ok($path => {Accept => 'text/json'});
    $driver->status_is(404);

    return 1;
}

sub get200 {
    my ($class, $restTest, $driver) = @_;

    #Make the HTTP request
    my $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'});
    $driver->status_is(200);
    $driver->json_has('email', 'Got something meaningful');
}

1;