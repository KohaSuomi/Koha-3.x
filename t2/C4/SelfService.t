#!perl

use Modern::Perl '2014';
use Test::More;
use Test::MockModule;
use Try::Tiny;

use DateTime;
use Scalar::Util qw(blessed);
use File::Basename;

use C4::SelfService;
use C4::Members::Attributes;
use Koha::Borrower::Debarments;
use lib File::Basename::dirname($INC{"C4/SelfService.pm"})."/../C4/SIP"; #Find where the SIP-server libraries are
use ILS::Patron;

use t::lib::TestContext;
use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::FinesFactory;

my $todayYmd = DateTime->now()->ymd('-');
my $testBorrowerCardnumber = 'Sanzabar';

my $globalContext = {};
my $SSAPIAuthorizerUser;
sub setGlobalContext {
    $SSAPIAuthorizerUser = t::lib::TestContext::setUserenv({cardnumber => 'SSAPIUser'}, $globalContext);
}
setGlobalContext();


subtest "HasSelfServiceAgreement with a finely behaving library user", \&HasSelfServiceAgreement_happy_path;
sub HasSelfServiceAgreement_happy_path {
    my $testContext = {};
    my ($b, $ilsPatron, $rv);
    eval { #start

    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({cardnumber => $testBorrowerCardnumber}, undef, $testContext);
    $ilsPatron = ILS::Patron->new($b->cardnumber);

    try {
        $rv = C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
        ok(0 , "Finely behaving user hasn't agreed to terms and conditions of self-service usage");
    } catch {
        ok(blessed($_) && $_->isa('Koha::Exception::SelfService::TACNotAccepted') , "Finely behaving user hasn't agreed to terms and conditions of self-service usage");
    };

    C4::Members::Attributes::SetBorrowerAttributes($b->borrowernumber, [{ code => 'SST&C', value => '1' }]);
    ok(C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor'), "Finely behaving user agreed to T&C and now has the permission.");

    ##Check for log entries
    my $logs = C4::SelfService::GetAccessLogs($ilsPatron->{borrowernumber});
    testLogs($logs, 0, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'missingT&C');
    testLogs($logs, 1, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'granted');

    }; #stop
    if ($@) {
        ok(0, $@);
    }
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
    C4::SelfService::FlushLogs();
}


subtest "HasSelfServiceAgreement with an underage user", \&HasSelfServiceAgreement_underage;
sub HasSelfServiceAgreement_underage {
    my $testContext = {};
    my ($b, $ilsPatron, $rv);
    eval { #start

    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({cardnumber => $testBorrowerCardnumber,
                                                                dateofbirth => $todayYmd},
                                                               undef, $testContext);
    $ilsPatron = ILS::Patron->new($b->cardnumber);

    try {
        $rv = C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
        ok(0 , "Underage user has no permission");
    } catch {
        ok(blessed($_) && $_->isa('Koha::Exception::SelfService::Underage') , "Underage user has no permission");
    };

    C4::Members::Attributes::SetBorrowerAttributes($b->borrowernumber, [{ code => 'SST&C', value => '1' }]);
    try {
        $rv = C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
        ok(0 , "Underage user agreed to T&C but still has no permission.");
    } catch {
        ok(blessed($_) && $_->isa('Koha::Exception::SelfService::Underage') , "Underage user agreed to T&C but still has no permission.");
    };

    ##Check for log entries
    my $logs = C4::SelfService::GetAccessLogs($ilsPatron->{borrowernumber});
    testLogs($logs, 0, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'underage');
    testLogs($logs, 1, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'underage');

    }; #stop
    if ($@) {
        ok(0, $@);
    }
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
    C4::SelfService::FlushLogs();
}


subtest "Bad customer has fines and debarment", \&BadCustomer;
sub BadCustomer {
    my $testContext = {};
    my $finesContext = {};
    my ($b, $f, $ilsPatron, $rv, $debarment);
    eval { #start

    ## Borrower with a lot of fines and a debarment and a agreed T&C
    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({cardnumber => $testBorrowerCardnumber}, undef, $testContext);
    C4::Members::Attributes::SetBorrowerAttributes($b->borrowernumber, [{ code => 'SST&C', value => '1' }]);
    Koha::Borrower::Debarments::AddDebarment({borrowernumber => $b->borrowernumber});
    $debarment = Koha::Borrower::Debarments::GetDebarments({borrowernumber => $b->borrowernumber})->[0];
    $ilsPatron = ILS::Patron->new($b->cardnumber);

    try {
        $rv = C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
        ok(0 , "User has no permission");
    } catch {
        ok(blessed($_) && $_->isa('Koha::Exception::SelfService') , "User has no permission");
    };

    Koha::Borrower::Debarments::DelDebarment($debarment->{borrower_debarment_id});
    $ilsPatron = ILS::Patron->new($b->cardnumber); #Refresh reference to ILS::Patron
    ok(C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor'), "Bad user has redeemed his debarment and now has the permission.");

    ## Borrower gets a huge fine :(
    $f = t::lib::TestObjects::FinesFactory->createTestGroup({amount => 1000, note => 'fid', cardnumber => $b->cardnumber}, 'cardnumber', $finesContext);
    $ilsPatron = ILS::Patron->new($b->cardnumber); #Refresh reference to ILS::Patron
    try {
        $rv = C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
        ok(0 , "User has no permission");
    } catch {
        ok(blessed($_) && $_->isa('Koha::Exception::SelfService') , "User has no permission");
    };

    # Fines are paid.
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($finesContext);
    $ilsPatron = ILS::Patron->new($b->cardnumber); #Refresh reference to ILS::Patron
    ok(C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor'), "Bad user has paid his fines and now has the permission.");

    ##Check for log entries
    my $logs = C4::SelfService::GetAccessLogs($ilsPatron->{borrowernumber}, 'CPL');
    testLogs($logs, 0, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'denied');
    testLogs($logs, 1, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'granted');
    testLogs($logs, 2, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'denied');
    testLogs($logs, 3, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'granted');

    }; #stop
    if ($@) {
        ok(0, $@);
    }
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
    C4::SelfService::FlushLogs();
}


sub tearDownGlobalContext {
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($globalContext);
}
tearDownGlobalContext();

done_testing();


sub testLogs {
    my ($logs, $i, $borrowernumber, $action, $ymd, $resolution) = @_;

    ok($logs->[$i]->{timestamp} =~ /^$ymd/, "Log entry $i, timestamp kinda ok");
    is($logs->[$i]->{user}, $SSAPIAuthorizerUser->borrowernumber, "Log entry $i, correct user");
    is($logs->[$i]->{module}, 'SS', "Log entry $i, correct module");
    is($logs->[$i]->{action}, $action, "Log entry $i, correct action");
    is($logs->[$i]->{object}, $borrowernumber, "Log entry $i, correct branch");
    is($logs->[$i]->{info}, $resolution, "Log entry $i, resolution ok");
}