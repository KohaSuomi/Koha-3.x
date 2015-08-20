#!/usr/bin/perl

# Copyright 2015 Open Source Freedom Fighters
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
use Try::Tiny;
use Encode;

use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::AtomicUpdateFactory;
use t::lib::TestObjects::FileFactory;
use Koha::AtomicUpdater;

my $testContext = {};
my $atomicupdates = t::lib::TestObjects::AtomicUpdateFactory->createTestGroup([
                           {issue_id => 'Bug12',
                            filename => 'Bug12-WatchExMachinaYoullLikeIt.pl'},
                           {issue_id => 'Bug14',
                            filename => 'Bug14-ReturnOfZorro.perl'},
                           {issue_id => '#14',
                            filename => '#14-RobotronInDanger.sql'},
                           {issue_id => '#15',
                            filename => '#15-ILikedPrometheusButAlienWasBetter.pl'},
                           ], undef, $testContext);

#Make sure we get the correct update order, otherwise we get unpredictable results.
{ #Overload existing subroutines to provide a Mock implementation
    no warnings 'redefine';
    package Koha::AtomicUpdater;
    sub _getGitCommits { #instead of requiring a Git repository, we just mock the input.
        return [#Newest commit
                '2e8a39762b506738195f21c8ff67e4e7bfe6d7ab #:-55 : Fiftyfive',
                '2e8a39762b506738195f21c8ff67e4e7bfe6d7ab #54 - KohaCon in Finland next year',
                'b447b595acacb0c4823582acf9d8a08902118e59 #53 - Place to be.pl',
                '2e8a39762b506738195f21c8ff67e4e7bfe6d7ab bug 112 - Lapinlahden linnut',
                '5ac7101d4071fe11f7a5d1445bb97ed1a603a9b5 Bug:-911 - What are you going to do?',
                '1d54601b9cac0bd75ee97e071cf52ed49daef8bd #911 - Who are you going to call',
                '1d54601b9cac0bd75ee97e071cf52ed49daef8bd bug 30 - Feature Yes yes',
                '5ac7101d4071fe11f7a5d1445bb97ed1a603a9b5 #-29 - Bug squashable',
                '2e8a39762b506738195f21c8ff67e4e7bfe6d7ab Bug :- 28 - Feature Squash',
                'b447b595acacb0c4823582acf9d8a08902118e59 BUG 27 - Bug help',
                #Oldest commit
                ];
    }
}

subtest "Create update order from Git repository" => \&createUpdateOrderFromGit;
sub createUpdateOrderFromGit {
    eval {
        #Create the _updateorder-file to a temp directory and prepare it for autocleanup.
        my $files = t::lib::TestObjects::FileFactory->createTestGroup([
                        {   filepath => 'atomicupdate/',
                            filename => '_updateorder',
                            content  => '',},
                        ],
                        undef, undef, $testContext);
        #Instantiate the AtomicUpdater to operate on a temp directory.
        my $atomicUpdater = Koha::AtomicUpdater->new({
                                        scriptDir => $files->{'_updateorder'}->dirname(),
                            });

        #Start real testing.
        my $issueIds = $atomicUpdater->buildUpdateOrderFromGit(4);

        is($issueIds->[0],
           'Bug27',
           "First atomicupdate to deploy");
        is($issueIds->[1],
           'Bug28',
           "Second atomicupdate to deploy");
        is($issueIds->[2],
           '#29',
           "Third atomicupdate to deploy");
        is($issueIds->[3],
           'Bug30',
           "Last atomicupdate to deploy");

        #Testing file access
        $issueIds = $atomicUpdater->getUpdateOrder();
        is($issueIds->[0],
           'Bug27',
           "First atomicupdate to deploy, from _updateorder");
        is($issueIds->[1],
           'Bug28',
           "Second atomicupdate to deploy, from _updateorder");
        is($issueIds->[2],
           '#29',
           "Third atomicupdate to deploy, from _updateorder");
        is($issueIds->[3],
           'Bug30',
           "Last atomicupdate to deploy, from _updateorder");
    };
    if ($@) {
        ok(0, $@);
    }
}



subtest "List all deployed atomicupdates" => \&listAtomicUpdates;
sub listAtomicUpdates {
    eval {
    my $atomicUpdater = Koha::AtomicUpdater->new();
    my $text = $atomicUpdater->listToConsole();
    print $text;

    ok($text =~ m/Bug12-WatchExMachinaYoullLik/,
       "Bug12-WatchExMachinaYoullLikeIt");
    ok($text =~ m/Bug14-ReturnOfZorro.perl/,
       "Bug14-ReturnOfZorro");
    ok($text =~ m/#14-RobotronInDanger.sql/,
       "#14-RobotronInDanger");
    ok($text =~ m/#15-ILikedPrometheusButAli/,
       "#15-ILikedPrometheusButAlienWasBetter");

    };
    if ($@) {
        ok(0, $@);
    }
}

subtest "Delete an atomicupdate entry" => \&deleteAtomicupdate;
sub deleteAtomicupdate {
    eval {
    my $atomicUpdater = Koha::AtomicUpdater->new();
    my $atomicupdate = $atomicUpdater->cast($atomicupdates->{Bug12}->id);
    ok($atomicupdate,
       "AtomicUpdate '".$atomicupdates->{Bug12}->issue_id."' exists prior to deletion");

    $atomicUpdater->removeAtomicUpdate($atomicupdate->issue_id);
    $atomicupdate = $atomicUpdater->find($atomicupdates->{Bug12}->id);
    ok(not($atomicupdate),
       "AtomicUpdate '".$atomicupdates->{Bug12}->issue_id."' deleted");

    };
    if ($@) {
        ok(0, $@);
    }
}

subtest "Insert an atomicupdate entry" => \&insertAtomicupdate;
sub insertAtomicupdate {
    eval {
    my $atomicUpdater = Koha::AtomicUpdater->new();
    my $subtestContext = {};
    my $atomicupdates = t::lib::TestObjects::AtomicUpdateFactory->createTestGroup([
                           {issue_id => 'Bug15',
                            filename => 'Bug15-Inserted.pl'},
                           ], undef, $subtestContext, $testContext);
    my $atomicupdate = $atomicUpdater->find({issue_id => 'Bug15'});
    ok($atomicupdate,
       "Bug15-Inserted.pl");

    t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);

    $atomicupdate = $atomicUpdater->find({issue_id => 'Bug15'});
    ok(not($atomicupdate),
       "Bug15-Inserted.pl deleted");
    };
    if ($@) {
        ok(0, $@);
    }
}

subtest "List pending atomicupdates" => \&listPendingAtomicupdates;
sub listPendingAtomicupdates {
    my ($atomicUpdater, $files, $text, $atomicupdates);
    my $subtestContext = {};
    eval {
    ##Test adding update scripts and deploy them, confirm that no pending scripts detected
    $files = t::lib::TestObjects::FileFactory->createTestGroup([
                        {   filepath => 'atomicupdate/',
                            filename => '#911-WhoYouGonnaCall.pl',
                            content  => '$ENV{ATOMICUPDATE_TESTS} = 1;',},
                        {   filepath => 'atomicupdate/',
                            filename => 'Bug911-WhatchaGonnaDo.pl',
                            content  => '$ENV{ATOMICUPDATE_TESTS}++;',},
                        {   filepath => 'atomicupdate/',
                            filename => 'Bug112-LapinlahdenLinnut.pl',
                            content  => '$ENV{ATOMICUPDATE_TESTS}++;',},
                        ],
                        undef, $subtestContext, $testContext);
    $atomicUpdater = Koha::AtomicUpdater->new({
                            scriptDir => $files->{'#911-WhoYouGonnaCall.pl'}->dirname()
                        });

    $text = $atomicUpdater->listPendingToConsole();
    print $text;

    ok($text =~ m/#911-WhoYouGonnaCall.pl/,
       "#911-WhoYouGonnaCall is pending");
    ok($text =~ m/Bug911-WhatchaGonnaDo.pl/,
       "Bug911-WhatchaGonnaDo is pending");
    ok($text =~ m/Bug112-LapinlahdenLinnut.pl/,
       'Bug112-LapinlahdenLinnut is pending');

    $atomicupdates = $atomicUpdater->applyAtomicUpdates();
    t::lib::TestObjects::AtomicUpdateFactory->addToContext($atomicupdates, undef, $subtestContext, $testContext); #Keep track of changes

    is($atomicupdates->{'#911'}->issue_id,
       '#911',
       "#911-WhoYouGonnaCall.pl deployed");
    is($atomicupdates->{'Bug112'}->issue_id,
       'Bug112',
       'Bug112-LapinlahdenLinnut.pl deployed');
    is($atomicupdates->{'Bug911'}->issue_id,
       'Bug911',
       "Bug911-WhatchaGonnaDo.pl deployed");

    ##Test adding scripts to the atomicupdates directory and how we deal with such change.
    $files = t::lib::TestObjects::FileFactory->createTestGroup([
                        {   filepath => 'atomicupdate/',
                            filename => '#53-PlaceToBe.pl',
                            content  => '$ENV{ATOMICUPDATE_TESTS}++;',},
                        {   filepath => 'atomicupdate/',
                            filename => '#54-KohaConInFinlandNextYear.pl',
                            content  => '$ENV{ATOMICUPDATE_TESTS}++;',},
                        {   filepath => 'atomicupdate/',
                            filename => '#55-Fiftyfive.pl',
                            content  => '$ENV{ATOMICUPDATE_TESTS}++;',},
                        ],
                        undef, $subtestContext, $testContext);

    $text = $atomicUpdater->listPendingToConsole();
    print $text;

    ok($text =~ m/#53-PlaceToBe.pl/,
       "#53-PlaceToBe.pl is pending");
    ok($text =~ m/#54-KohaConInFinlandNextYear.pl/,
       "#54-KohaConInFinlandNextYear.pl is pending");
    ok($text =~ m/#55-Fiftyfive.pl/u,
       '#55-Fiftyfive.pl');

    $atomicupdates = $atomicUpdater->applyAtomicUpdates();
    t::lib::TestObjects::AtomicUpdateFactory->addToContext($atomicupdates, undef, $subtestContext, $testContext); #Keep track of changes

    is($atomicupdates->{'#53'}->issue_id,
       '#53',
       "#53-PlaceToBe.pl deployed");
    is($atomicupdates->{'#54'}->issue_id,
       '#54',
       '#54-KohaConInFinlandNextYear.pl deployed');
    is($atomicupdates->{'#55'}->issue_id,
       '#55',
       "#55-Fiftyfive.pl deployed");

    is($ENV{ATOMICUPDATE_TESTS},
       6,
       "All configured AtomicUpdates deployed");
    };
    if ($@) {
        ok(0, $@);
    }
    t::lib::TestObjects::AtomicUpdateFactory->tearDownTestContext($subtestContext);
}

t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
done_testing;