#!perl

use Modern::Perl '2014';
use Test::More;

use C4::Matcher;
use C4::Search;

use t2::C4::Matcher_context;
use t::lib::TestObjects::ObjectFactory;

my $testContext = {};
my $records = t2::C4::Matcher_context::createTwoDuplicateRecords($testContext);
my $matcher = t2::C4::Matcher_context::createControlNumberMatcher($testContext);

subtest "Match duplicates", \&matchDuplicates;
sub matchDuplicates {
    eval {
        C4::Search::reindexZebraChanges();
        my @matches = $matcher->get_matches($records->{'889853057023first'}, 5);
        is(scalar(@matches), 2, "Got two duplicate records");
    };
    if ($@) {
        ok(0, $@);
    }
}

t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);

done_testing();
1;
