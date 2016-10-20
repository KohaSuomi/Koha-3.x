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

use t2::C4::SelfService_context;
use t::lib::TestContext;
use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::SystemPreferenceFactory;

my $todayYmd = DateTime->now()->ymd('-');
my $testBorrowerCardnumber = 'Sanzabar';

my $globalContext = {};
my $SSAPIAuthorizerUser;
sub setGlobalContext {
    $SSAPIAuthorizerUser = t::lib::TestContext::setUserenv({cardnumber => 'SSAPIUser'}, $globalContext);
}
setGlobalContext();



subtest "Age limit threshold tests", \&ageLimit;
sub ageLimit {
    my $testContext = {};
    my ($b, $ilsPatron, $rv);
    eval { #start

    ## Set the age limit ##
    t::lib::TestObjects::SystemPreferenceFactory->createTestGroup({
        preference => 'SSRules',
        value => '15:PT S',
    }, undef, $testContext);

    $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({cardnumber => $testBorrowerCardnumber,
                                                                dateofbirth => $todayYmd},
                                                               undef, $testContext);
    C4::Members::Attributes::SetBorrowerAttributes($b->borrowernumber, [{ code => 'SST&C', value => '1' }]);
    $ilsPatron = ILS::Patron->new($b->cardnumber);

    try {
        $rv = C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
        ok(0 , "Underage user has no permission");
    } catch {
        ok(blessed($_) && $_->isa('Koha::Exception::SelfService::Underage') , "Underage user has no permission");
    };

    ## Disable age limit alltogether ##
    t::lib::TestObjects::SystemPreferenceFactory->createTestGroup({
        preference => 'SSRules',
        value => '0:PT S',
    }, undef, $testContext);

    ok(C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor'),
       "Underage user agreed to T&C but still has no permission.");

    ##Check for log entries
    my $logs = C4::SelfService::GetAccessLogs($ilsPatron->{borrowernumber});
    t2::C4::SelfService_context::testLogs($logs, 0, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'underage', $SSAPIAuthorizerUser);
    t2::C4::SelfService_context::testLogs($logs, 1, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'granted',  $SSAPIAuthorizerUser);

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
