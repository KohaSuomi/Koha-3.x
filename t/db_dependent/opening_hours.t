use Modern::Perl;
use Test::More;
use DateTime;
use Try::Tiny;
use Scalar::Util qw(blessed);

use t::lib::TestObjects::SystemPreferenceFactory;
use t::lib::TestObjects::ObjectFactory;
use t::db_dependent::opening_hours_context;

use C4::Branch;

my $testContext = {};

my $now = DateTime->now(
            time_zone => C4::Context->tz,
            ##Introduced as a infile-package
            formatter => HMFormatter->new()
);
#If it is not monday, turn back time until it is.
my $weekday = $now->day_of_week;
my $startOfWeek = ($weekday > 1) ? $now->clone->subtract(days => $weekday-1) : $now->clone;

t::db_dependent::opening_hours_context::createContext($testContext);


subtest "Opening hours happy path", \&openingHoursHappyPath;
sub openingHoursHappyPath {
    eval {

    ok(C4::Branch::isOpen('CPL'),
        'Branch CPL is open now');
    ok(C4::Branch::isOpen('FFL'),
        'Branch FFL has just opened');
    sleep(1); #Wait a second, because ending time is inclusive.
    ok(! C4::Branch::isOpen('IPL'),
        'Branch IPL has just closed');
    ok(! C4::Branch::isOpen('MPL'),
        'Branch MPL is closed');

    };
    ok(0, $@) if $@;
}


subtest "Opening hours exceptions", \&openingHoursExceptions;
sub openingHoursExceptions {
    my ($testName, $today);
    my $subtestContext = {};

    eval {

    ##TEST 1
    $testName = 'LPL throws exception because it is completely missing opening hours.';
    try {
        C4::Branch::isOpen('LPL');
        ok(0, "Test: $testName failed. We should get exception instead!");
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::FeatureUnavailable')) {
            ok(1, $testName);
        } else {
            ok(0, "Test: $testName failed. $_");
        }
    };


    ##TEST 1.1
    $testName = 'IPT throws exception because it is missing opening hours for one day.';
    try {
        #Rewind to Sunday, Sunday is missing opening hours.
        $today = $startOfWeek->clone->add(days => 6);
        C4::Branch::isOpen('IPT', $today);
        ok(0, "Test: $testName failed. We should get exception instead!");
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::FeatureUnavailable')) {
            ok(1, $testName);
        } else {
            ok(0, "Test: $testName failed. $_");
        }
    };


    ##TEST 2
    $testName = 'Throws exception because OpeningHours-syspref is malformed.';
    t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([
                    {preference => 'OpeningHours',
                     #Value is JSON as text, which is not YAML as text
                     value      => "{
                         CPL => {
                             startTime => $now->clone->subtract(hours => 3)->iso8601,
                             endTime   => $now->clone->add(     hours => 3)->iso8601,
                         },
                     }",
                    },
                ], undef, $subtestContext);

    try {
        C4::Branch::isOpen('CPL');
        ok(0, "Test: $testName failed. We should get exception instead!");
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::BadSystemPreference')) {
            ok(1, $testName);
        } else {
            ok(0, "Test: $testName failed. $_");
        }
    };


    ##TEST 3
    $testName = 'Throws exception because OpeningHours-syspref is missing.';
    t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([
                    {preference => 'OpeningHours',
                     value      => '',
                    },
                ], undef, $subtestContext);

    try {
        C4::Branch::isOpen('IPT');
        ok(0, "Test: $testName failed. We should get exception instead!");
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::NoSystemPreference')) {
            ok(1, $testName);
        } else {
            ok(0, "Test: $testName failed. $_");
        }
    };


    t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);
    };
    ok(0, $@) if $@;
}


subtest "Daily opening hours", \&dailyOpeningHours;
sub dailyOpeningHours {
    my ($today);

    eval {

    ok(1, 'Given we are accessing branch IPT');
    ok($today = $startOfWeek->clone->set_hour(6)->set_minute(45),
        'And today is monday 06:45');
    ok(! C4::Branch::isOpen('IPT', $today),
        'Then the branch is closed');

    ok($today = $today->set_hour(7)->set_minute(0),
        'Given today is monday 07:00');
    ok(C4::Branch::isOpen('IPT', $today),
        'Then the branch has just opened');

    ok($today = $today->set_hour(20)->set_minute(0),
        'Given today is monday 20:00');
    ok(! C4::Branch::isOpen('IPT', $today),
        'Then the branch has just closed');

    ok($today = $today->set_hour(19)->set_minute(59),
        'Given today is monday 19:59');
    ok(C4::Branch::isOpen('IPT', $today),
        'Then the branch is open but just closing');

    ok($today = $startOfWeek->clone->set_hour(9)->set_minute(45)->add(days => 5),
        'And today is saturday 09:45');
    ok(! C4::Branch::isOpen('IPT', $today),
        'Then the branch is closed');

    ok($today = $today->set_hour(10)->set_minute(0),
        'Given today is saturday 10:00');
    ok(C4::Branch::isOpen('IPT', $today),
        'Then the branch has just opened');

    ok($today = $today->set_hour(17)->set_minute(55),
        'Given today is saturday 17:55');
    ok(C4::Branch::isOpen('IPT', $today),
        'Then the branch is just closing');

    ok($today = $today->set_hour(18)->set_minute(0),
        'Given today is saturday 18:00');
    ok(! C4::Branch::isOpen('IPT', $today),
        'Then the branch has just closed');

    };
    ok(0, $@) if $@;
}


t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
done_testing;


{
## Simple formatter for DateTime to be used in test context generation
package HMFormatter;

sub new {
  return bless({}, __PACKAGE__);
}
sub format_datetime {
  return sprintf("%02d:%02d", $_[1]->hour, $_[1]->minute);
}
} ##EO package HMFormatter
