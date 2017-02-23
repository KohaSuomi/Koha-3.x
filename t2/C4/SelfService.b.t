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
use C4::Members;
use Koha::Borrower::Debarments;
use lib File::Basename::dirname($INC{"C4/SelfService.pm"})."/../C4/SIP"; #Find where the SIP-server libraries are
use ILS::Patron;

use t2::C4::SelfService_context;
use t::db_dependent::opening_hours_context;
use t::lib::TestContext;
use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::FinesFactory;
use t::lib::TestObjects::SystemPreferenceFactory;

my $globalContext = {};
my $todayYmd = DateTime->now()->ymd('-');
my $testBorrowerCardnumber = 'Sanzabar';
my $SSAPIAuthorizerUser = t::lib::TestContext::setUserenv({cardnumber => 'SSAPIUser'}, $globalContext);


subtest("Scenario: User with all possible blocks and bans tries to access a Self-Service resource. Testing that exceptions are reported in the correct order.", sub {

    my $scenarioContext = {};
    my $finesContext = {}; #Save fines here to be tore down later
    my $b; #Scenario borrower
    my $ilsPatron; #Scenario ILS patron
    my $debarment; #Debarment of the scenario borrower
    my $f; #Fines of the scenario borrower

    eval {
    subtest("Set opening hours", sub {
        ok(t::db_dependent::opening_hours_context::createContext($scenarioContext));
    });
    subtest("Clear system preference 'SSRules'", sub {
        t::lib::TestObjects::SystemPreferenceFactory->createTestGroup({
            preference => 'SSRules',
            value => '',
        }, undef, $scenarioContext);
        ok(1, "Step ok");
    });
    subtest("Given a user with all relevant blocks and bans", sub {
        $b = t::lib::TestObjects::BorrowerFactory->createTestGroup({cardnumber => $testBorrowerCardnumber,
                                                                    dateofbirth => $todayYmd,
                                                                    categorycode => 'ST'},
                                                                   undef, $scenarioContext);

        C4::Members::Attributes::SetBorrowerAttributes($b->borrowernumber, [{ code => 'SSBAN', value => '1' }]);

        Koha::Borrower::Debarments::AddDebarment({borrowernumber => $b->borrowernumber});
        $debarment = Koha::Borrower::Debarments::GetDebarments({borrowernumber => $b->borrowernumber})->[0];
        $f = t::lib::TestObjects::FinesFactory->createTestGroup({amount => 1000, note => 'fid', cardnumber => $b->cardnumber}, 'cardnumber', $scenarioContext, $finesContext);
        ok(1, "Step ok");
    });
    subtest("Self-service resource accessing is not properly configured", sub {
        $ilsPatron = ILS::Patron->new($b->cardnumber);

        try {
            C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
            ok(0 , "EXPECTED EXCEPTION");
        } catch {
            ok(blessed($_) && $_->isa('Koha::Exception::FeatureUnavailable') , "System preferences not properly set");
        };
    });
    subtest("Given a system preference 'SSRules', which has age limit of 15 years and allows borrower categories 'PT S'", sub {
        t::lib::TestObjects::SystemPreferenceFactory->createTestGroup({
            preference => 'SSRules',
            value => '15:PT S',
        }, undef, $scenarioContext);
        ok(1, "Step ok");
    });
    subtest("Self-service feature works, but terms and conditions are not accepted", sub {
        $ilsPatron = ILS::Patron->new($b->cardnumber);

        try {
            C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
            ok(0 , "EXPECTED EXCEPTION");
        } catch {
            ok(blessed($_) && $_->isa('Koha::Exception::SelfService::TACNotAccepted') , "Finely behaving user hasn't agreed to terms and conditions of self-service usage");
        };
    });
    subtest("Self-service terms and conditions accepted, but user's self-service permissions have been revoked", sub {
        C4::Members::Attributes::SetBorrowerAttributes($b->borrowernumber, [{ code => 'SST&C', value => '1' },
                                                                            { code => 'SSBAN', value => '1' }]);
        $ilsPatron = ILS::Patron->new($b->cardnumber);

        try {
            C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
            ok(0 , "EXPECTED EXCEPTION");
        } catch {
            ok(blessed($_) && $_->isa('Koha::Exception::SelfService::PermissionRevoked') , "User Self-Service permission revoked");
        };
    });
    subtest("Self-service permission reinstituted, but the user has a wrong borrower category", sub {
        C4::Members::Attributes::SetBorrowerAttributes($b->borrowernumber, [{ code => 'SST&C', value => '1' },
                                                                            { code => 'SSBAN', value => '0' }]);
        $ilsPatron = ILS::Patron->new($b->cardnumber);

        try {
            C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
            ok(0 , "EXPECTED EXCEPTION");
        } catch {
            ok(blessed($_) && $_->isa('Koha::Exception::SelfService::BlockedBorrowerCategory') , "User's borrower category is not whitelisted");
        };
    });
    subtest("Borrower category changed, but the user is still underaged", sub {
        $b->categorycode('PT'); $b->store();
        $ilsPatron = ILS::Patron->new($b->cardnumber);

        try {
            C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
            ok(0 , "EXPECTED EXCEPTION");
        } catch {
            ok(blessed($_) && $_->isa('Koha::Exception::SelfService::Underage') , "Underage user has no permission");
        };
    });
    subtest("Borrower grew up, but is still debarred", sub {
        $b->dateofbirth('2000-01-01'); $b->store();
        $ilsPatron = ILS::Patron->new($b->cardnumber);

        try {
            C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
            ok(0 , "EXPECTED EXCEPTION");
        } catch {
            ok(blessed($_) && $_->isa('Koha::Exception::SelfService') , "User has no permission");
        };
    });
    subtest("Borrower debarment lifted, but still has too many fines", sub {
        Koha::Borrower::Debarments::DelDebarment($debarment->{borrower_debarment_id});
        $ilsPatron = ILS::Patron->new($b->cardnumber);

        try {
            C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor');
            ok(0 , "EXPECTED EXCEPTION");
        } catch {
            ok(blessed($_) && $_->isa('Koha::Exception::SelfService') , "User has no permission");
        };
    });
    subtest("Borrower is cleaned from his sins, but still the library is closed", sub {
        t::lib::TestObjects::ObjectFactory->tearDownTestContext($finesContext);
        $ilsPatron = ILS::Patron->new($b->cardnumber);

        try {
            C4::SelfService::CheckSelfServicePermission($ilsPatron, 'UPL', 'accessMainDoor');
            ok(0 , "EXPECTED EXCEPTION");
        } catch {
            ok(blessed($_) && $_->isa('Koha::Exception::SelfService::OpeningHours') , "Library is closed");
        };
    });
    subtest("Borrower tries another library and is allowed access", sub {
        ok(C4::SelfService::CheckSelfServicePermission($ilsPatron, 'CPL', 'accessMainDoor'),
           "Finely behaving user accesses a self-service resource.");
    });
    subtest("Check the log entries", sub {
        my $logs = C4::SelfService::GetAccessLogs($b->borrowernumber);
        t2::C4::SelfService_context::testLogs($logs, 0, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'misconfigured', $SSAPIAuthorizerUser);
        t2::C4::SelfService_context::testLogs($logs, 1, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'missingT&C',    $SSAPIAuthorizerUser);
        t2::C4::SelfService_context::testLogs($logs, 2, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'revoked',       $SSAPIAuthorizerUser);
        t2::C4::SelfService_context::testLogs($logs, 3, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'blockBorCat',   $SSAPIAuthorizerUser);
        t2::C4::SelfService_context::testLogs($logs, 4, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'underage',      $SSAPIAuthorizerUser);
        t2::C4::SelfService_context::testLogs($logs, 5, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'denied',        $SSAPIAuthorizerUser);
        t2::C4::SelfService_context::testLogs($logs, 6, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'denied',        $SSAPIAuthorizerUser);
        t2::C4::SelfService_context::testLogs($logs, 7, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'closed',        $SSAPIAuthorizerUser);
        t2::C4::SelfService_context::testLogs($logs, 8, $b->borrowernumber, 'accessMainDoor', $todayYmd, 'granted',       $SSAPIAuthorizerUser);
    });
    };
    if ($@) {
        ok(0, $@);
    }
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($scenarioContext);
    C4::SelfService::FlushLogs();
});


t::lib::TestObjects::ObjectFactory->tearDownTestContext($globalContext);
done_testing();
