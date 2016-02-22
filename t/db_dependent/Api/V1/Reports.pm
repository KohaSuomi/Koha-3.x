package t::db_dependent::Api::V1::Reports;

# Copyright 2016 KohaSuomi
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Test::More;

use C4::BatchOverlay::ReportManager;
use C4::BatchOverlay::RuleManager;

use t::CataloguingCenter::ContextSysprefs;
use t::db_dependent::Biblio::Diff::localRecords;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::ObjectFactory;

sub getbatchOverlays200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    _setUpTestContext($restTest, $driver);

    #Execute request
    my $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    $driver->json_is('/0/borrowernumber' => $activeUser->borrowernumber, "Got borrowernumber");
    $driver->json_is('/1/borrowernumber' => undef, "No second report container");

    C4::BatchOverlay::ReportManager->removeReports({do => 1});
}
sub getbatchOverlays404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();
    #Execute request
    my $path = $restTest->get_routePath();
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);

    $driver->json_is('/0/borrowernumber' => undef, "No report containers");
}
sub getbatchOverlays_n_reports200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path);
    my $reportContainer = _setUpTestContext($restTest, $driver);

    #Execute request with default exception classes requested
    $path = $restTest->get_routePath( $reportContainer->getId() );
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    $driver->json_is('/0/operation' => 'record merging', "Got report 1");
    $driver->json_is('/1/operation' => 'record merging', "Got report 2");
    $driver->json_is('/2/operation' => undef,            "No report 3");

    #Execute request with all exception classes
    $path = $restTest->get_routePath( $reportContainer->getId() );
    $driver->get_ok($path."?showAllExceptions=1" => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    $driver->json_is('/0/operation' => 'record merging', "Got report 1");
    $driver->json_is('/1/operation' => 'error',          "Got report 2 - excluded exception");
    $driver->json_is('/2/operation' => 'record merging', "Got report 3");
    $driver->json_is('/3/operation' => undef,            "No report 4");

    C4::BatchOverlay::ReportManager->removeReports({do => 1});
}
sub getbatchOverlays_n_reports404 {
    ok(1, "skipped");
}


sub _setUpTestContext {
    my ($restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();

    my $ruleManager = C4::BatchOverlay::RuleManager->new();
    t::CataloguingCenter::ContextSysprefs::createBatchOverlayRules($testContext);
    my $records = t::db_dependent::Biblio::Diff::localRecords::create($testContext);
    my @recKeys = sort(keys(%$records));

    my $errorBuilder = C4::BatchOverlay::ErrorBuilder->new();
    my $errorReport = $errorBuilder->addError(Koha::Exception::BatchOverlay::UnknownMatcher->new(error => "errordescription"),
                                              $records->{ $recKeys[0] },
                                              $ruleManager->getRuleFromRuleName('default'));
    my $reportContainer = C4::BatchOverlay::ReportContainer->new();
    $reportContainer->addReport(
        {   localRecord  => $records->{ $recKeys[0] },
            newRecord    => $records->{ $recKeys[1] },
            mergedRecord => $records->{ $recKeys[2] },
            operation => 'record merging',
            timestamp => DateTime->now( time_zone => C4::Context->tz() ),
            overlayRule => $ruleManager->getRuleFromRuleName('default'),
        }
    );
    $reportContainer->addReport(
        $errorReport,
    );
    $reportContainer->addReport(
        {   localRecord =>    $records->{ $recKeys[1] },
            newRecord =>    $records->{ $recKeys[2] },
            mergedRecord => $records->{ $recKeys[0] },
            operation => 'record merging',
            timestamp => DateTime->now( time_zone => C4::Context->tz() ),
            overlayRule => $ruleManager->getRuleFromRuleName('default'),
        }
    );
    $reportContainer->persist();
    return $reportContainer;
}

1;
