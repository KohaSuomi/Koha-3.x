$ENV{KOHA_PAGEOBJECT_DEBUG} = 1;
package t::db_dependent::Api::V1::Auth;

use Modern::Perl;
use Test::More;
use Data::Dumper;
use C4::Auth;
use C4::Context;
use Koha::Auth::PermissionManager;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::ObjectFactory;
use t::lib::Page::Mainpage;
use t::lib::Page::Opac::OpacMain;
use JSON;

sub getsession404 {
#    my ($class, $restTest, $driver) = @_;
#    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
#    my $activeUser = $restTest->get_activeBorrower();
#
#    #Create the test borrower.
#    my $b = [{ cardnumber => '11A01', firstname => 'Olli', surname => 'Kiivi', password => '1234', userid => 'admin', branchcode => 'CPL' }];
#    my $borrowers = t::lib::TestObjects::BorrowerFactory->createTestGroup($b, undef, $testContext, undef, undef);
#    $b = $borrowers->{'11A01'};
#    my $expectedResponse = {
#        email => $b->{email},
#        firstname => $b->{firstname},
#        lastname => $b->{lastname}
#    };
#    my $borrowernumber = $b->borrowernumber;
#
    #Execute request
#    my $path = $restTest->get_routePath();
#    print $path . "\n"
#    $path =~ s/\{borrowernumber\}/$borrowernumber/;
#    $driver->get_ok($path => {Accept => 'text/json'}, json => $expectedResponse);
#    $driver->status_is(200);

    #Compare result
#    $driver->json_is('/session' => $expectedResponse, "Got the same borrower '$borrowernumber'");
#    my $json = $driver->tx->res->json();
#    my $body = $driver->tx->res->body();

    return 1;
}

sub getsession400 {

    return 1;
}

sub getsession200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();
    my $permissionManager = Koha::Auth::PermissionManager->new();

    #Create the test borrower.
    my $b = [{ emailaddress => 'testinen@example.com', cardnumber => '11A01', firstname => 'Olli', surname => 'Kiivi', password => '1234', userid => 'admin', branchcode => 'CPL' }];
    my $borrowers = t::lib::TestObjects::BorrowerFactory->createTestGroup($b, undef, $testContext, undef, undef);

    $b = $borrowers->{'11A01'};
    $permissionManager->grantPermissions($b, {catalogue => 'staff_login'});
    my $session = C4::Auth::get_session();
    my $flags = C4::Auth::haspermission($b->userid, {catalogue => 'staff_login'});
    $session->param('number', $b->borrowernumber);
    $session->param('id', $b->userid);
    $session->param('cardnumber', $b->cardnumber);
    $session->param('firstname', $b->firstname);
    $session->param('surname', $b->surname);
    $session->param('branch', 'NO_LIBRARY_SET');
    $session->param('branchname', 'NO_LIBRARY_SET');
    $session->param('emailaddress', $b->email);
    $session->param('persona', undef);
    $session->param('flags', 1);
    $session->param('branchprinter', undef);

    my $sessionid = $session->id();


    print Dumper($session) . "\n";

    C4::Context->_new_userenv($sessionid);
    C4::Context::set_userenv(
        $session->param('number'),       $session->param('id'),
        $session->param('cardnumber'),   $session->param('firstname'),
        $session->param('surname'),      $session->param('branch'),
        $session->param('branchname'),   $session->param('flags'),
        $session->param('emailaddress'), $session->param('branchprinter'),
        $session->param('persona')
    );

#    my $main = t::lib::Page::Mainpage->new();
#    $main->doPasswordLogin($b->userid, $b->password);

#    print Dumper($main) . "\n";

    my $expectedResponse = {
        email => $b->email,
        firstname => $b->firstname,
        lastname => $b->surname
    };

    print 'Sessionid: ' . $sessionid . "\n";
    my $testedSession = {
        session => {
            sessionid => $sessionid
        }
    };

#    print Dumper $activeUser;
#    print Dumper $testContext;
#    print Dumper($testedSession) . "\n";

    #Execute request
    my $path = $restTest->get_routePath();
    print $path . "\n";
#    $path =~ s/\{borrowernumber\}/$borrowernumber/;
    $driver->get_ok($path => {Accept => 'text/json'} => {session => {sessionid => $sessionid}});
    print Dumper $driver;
    $driver->status_is(200);

    #Compare result
    $driver->json_is('/session' => $expectedResponse, "Got the same session!");
    my $json = $driver->tx->res->json();
    my $body = $driver->tx->res->body();

    return 1;
}

1;
