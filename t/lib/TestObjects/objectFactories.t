#!/usr/bin/perl

# Copyright Vaara-kirjastot 2015
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

use Modern::Perl;

use Test::More;
use DateTime;

use Koha::DateUtils;

use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::BorrowerFactory;
use Koha::Borrowers;
use t::lib::TestObjects::ItemFactory;
use Koha::Items;
use t::lib::TestObjects::AtomicUpdateFactory;
use Koha::AtomicUpdater;
use t::lib::TestObjects::BiblioFactory;
use Koha::Biblios;
use t::lib::TestObjects::CheckoutFactory;
use Koha::Checkouts;
use t::lib::TestObjects::LetterTemplateFactory;
use Koha::LetterTemplates;
use t::lib::TestObjects::FileFactory;
use File::Slurp;
use File::Fu::File;
use t::lib::TestObjects::SystemPreferenceFactory;
use t::lib::TestObjects::HoldFactory;
use C4::Context;


my $testContext = {}; #Gather all created Objects here so we can finally remove them all.



########## HoldFactory subtests ##########
subtest 't::lib::TestObjects::HoldFactory' => \&testHoldFactory;
sub testHoldFactory {
    my $subtestContext = {};
    ##Create and Delete using dependencies in the $testContext instantiated in previous subtests.
    my $holds = t::lib::TestObjects::HoldFactory->createTestGroup(
                        {cardnumber        => '1A01',
                         isbn              => '971',
                         barcode           => '1N01',
                         branchcode        => 'CPL',
                         waitingdate       => '2015-01-15',
                        },
                        ['cardnumber','isbn','barcode'], $subtestContext);

    is($holds->{'1A01-971-1N01'}->{branchcode},
       'CPL',
       "Hold '1A01-971-1N01' pickup location is 'CPL'.");
    is($holds->{'1A01-971-1N01'}->{waitingdate},
       '2015-01-15',
       "Hold '1A01-971-1N01' waiting date is '2015-01-15'.");

    #using the default test hold identifier reservenotes to distinguish hard-to-identify holds.
    my $holds2 = t::lib::TestObjects::HoldFactory->createTestGroup([
                        {cardnumber        => '1A01',
                         isbn              => '971',
                         barcode           => '1N02',
                         branchcode        => 'CPL',
                         reservenotes      => 'nice hold',
                        },
                        {cardnumber        => '1A01',
                         barcode           => '1N03',
                         isbn              => '971',
                         branchcode        => 'CPL',
                         reservenotes      => 'better hold',
                        },
                    ], undef, $subtestContext);

    is($holds2->{'nice hold'}->{branchcode},
        'CPL',
        "Hold 'nice hold' pickup location is 'CPL'.");
    is($holds2->{'nice hold'}->{borrower}->cardnumber,
        '1A01',
        "Hold 'nice hold' cardnumber is '1A01'.");
    is($holds2->{'better hold'}->{isbn},
        '971',
        "Hold 'better hold' isbn '971'.");

    t::lib::TestObjects::HoldFactory->deleteTestGroup($subtestContext->{hold});

    my $holds_deleted = C4::Reserves::GetReservesFromBiblionumber({biblionumber => $holds->{'1A01-971-1N01'}->{biblio}->{biblionumber}});
    ok (not(@$holds_deleted), "Holds deleted");
};



########## FileFactory subtests ##########
subtest 't::lib::TestObjects::FileFactory' => \&testFileFactory;
sub testFileFactory {
    my ($files);
    my $subtestContext = {};

    $files = t::lib::TestObjects::FileFactory->createTestGroup([
                        {'filepath' => 'atomicupdate',
                         'filename' => '#30-RabiesIsMyDog.pl',
                         'content' => 'print "Mermaids are my only love\nI never let them down";',
                        },
                        {'filepath' => 'atomicupdate',
                         'filename' => '#31-FrogsArePeopleToo.pl',
                         'content' => 'print "Listen to the Maker!";',
                        },
                        {'filepath' => 'atomicupdate',
                         'filename' => '#32-AnimalLover.pl',
                         'content' => "print 'Do not hurt them!;",
                        },
                    ], undef, $subtestContext);

    my $file30content = File::Slurp::read_file( $files->{'#30-RabiesIsMyDog.pl'}->absolutely );
    ok($file30content =~ m/Mermaids are my only love/,
       "'#30-RabiesIsMyDog.pl' created and content matches");
    my $file31content = File::Slurp::read_file( $files->{'#31-FrogsArePeopleToo.pl'}->absolutely );
    ok($file31content =~ m/Listen to the Maker!/,
       "'#31-FrogsArePeopleToo.pl' created and content matches");
    my $file32content = File::Slurp::read_file( $files->{'#32-AnimalLover.pl'}->absolutely );
    ok($file32content =~ m/Do not hurt them!/,
       "'#32-AnimalLover.pl' created and content matches");

    ##addToContext() test, create new file
    my $dir = $files->{'#32-AnimalLover.pl'}->dirname();
    my $file = File::Fu::File->new("$dir/addToContext.txt");
    $file->touch;
    t::lib::TestObjects::FileFactory->addToContext($file, undef, $subtestContext);
    ok($file->e,
       "'addToContext.txt' created");

    t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);

    ok(not(-e $files->{'#30-RabiesIsMyDog.pl'}->absolutely),
       "'#30-RabiesIsMyDog.pl' deleted");
    ok(not(-e $files->{'#31-FrogsArePeopleToo.pl'}->absolutely),
       "'#31-FrogsArePeopleToo.pl' deleted");
    ok(not(-e $files->{'#32-AnimalLover.pl'}->absolutely),
       "'#32-AnimalLover.pl' deleted");
    ok(not(-e $file->absolutely),
       "'addToContext.txt' deleted");
};



########## BorrowerFactory subtests ##########
subtest 't::lib::TestObjects::BorrowerFactory' => \&testBorrowerFactory;
sub testBorrowerFactory {
    my $subtestContext = {};
    ##Create and Delete. Add one
    my $f = t::lib::TestObjects::BorrowerFactory->new();
    my $objects = $f->createTestGroup([
                        {firstname => 'Olli-Antti',
                         surname   => 'Kivi',
                         cardnumber => '11A001',
                         branchcode     => 'CPL',
                        },
                    ], undef, $subtestContext, undef, $testContext);
    is($objects->{'11A001'}->cardnumber, '11A001', "Borrower '11A001'.");
    ##Add one more to test incrementing the subtestContext.
    $objects = $f->createTestGroup([
                        {firstname => 'Olli-Antti2',
                         surname   => 'Kivi2',
                         cardnumber => '11A002',
                         branchcode     => 'FFL',
                        },
                    ], undef, $subtestContext, undef, $testContext);
    is($subtestContext->{borrower}->{'11A001'}->cardnumber, '11A001', "Borrower '11A001' from \$subtestContext."); #From subtestContext
    is($objects->{'11A002'}->branchcode,                     'FFL',    "Borrower '11A002'."); #from just created hash.

    ##Delete objects
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);
    foreach my $cn (('11A001', '11A002')) {
        ok (not(Koha::Borrowers->find({cardnumber => $cn})),
            "Borrower '11A001' deleted");
    }

    #Prepare for global autoremoval.
    $objects = $f->createTestGroup([
                        {firstname => 'Olli-Antti',
                         surname   => 'Kivi',
                         cardnumber => '11A001',
                         branchcode     => 'CPL',
                        },
                        {firstname => 'Olli-Antti2',
                         surname   => 'Kivi2',
                         cardnumber => '11A002',
                         branchcode     => 'FFL',
                        },
                    ], undef, undef, undef, $testContext);
};



########## BiblioFactory and ItemFactory subtests ##########
subtest 't::lib::TestObjects::BiblioFactory and ::ItemFactory' => \&testBiblioItemFactories;
sub testBiblioItemFactories {
    my $subtestContext = {};
    ##Create and Delete. Add one
    my $biblios = t::lib::TestObjects::BiblioFactory->createTestGroup([
                        {'biblio.title' => 'I wish I met your mother',
                         'biblio.author'   => 'Pertti Kurikka',
                         'biblio.copyrightdate' => '1960',
                         'biblioitems.isbn'     => '9519671580',
                         'biblioitems.itemtype' => 'BK',
                        },
                    ], 'biblioitems.isbn', $subtestContext, undef, $testContext);
    my $objects = t::lib::TestObjects::ItemFactory->createTestGroup([
                        {biblionumber => $biblios->{9519671580}->{biblionumber},
                         barcode => '167Nabe0001',
                         homebranch   => 'CPL',
                         holdingbranch => 'CPL',
                         price     => '0.50',
                         replacementprice => '0.50',
                         itype => 'BK',
                         biblioisbn => '9519671580',
                         itemcallnumber => 'PK 84.2',
                        },
                    ], 'barcode', $subtestContext, undef, $testContext);

    is($objects->{'167Nabe0001'}->barcode, '167Nabe0001', "Item '167Nabe0001'.");
    ##Add one more to test incrementing the subtestContext.
    $objects = t::lib::TestObjects::ItemFactory->createTestGroup([
                        {biblionumber => $biblios->{9519671580}->{biblionumber},
                         barcode => '167Nabe0002',
                         homebranch   => 'CPL',
                         holdingbranch => 'FFL',
                         price     => '3.50',
                         replacementprice => '3.50',
                         itype => 'BK',
                         biblioisbn => '9519671580',
                         itemcallnumber => 'JK 84.2',
                        },
                    ], 'barcode', $subtestContext, undef, $testContext);

    is($subtestContext->{item}->{'167Nabe0001'}->barcode, '167Nabe0001', "Item '167Nabe0001' from \$subtestContext.");
    is($objects->{'167Nabe0002'}->holdingbranch,           'FFL',         "Item '167Nabe0002'.");
    is(ref($biblios->{9519671580}), 'MARC::Record', "Biblio 'I wish I met your mother'.");

    ##Delete objects
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);
    my $object1 = Koha::Items->find({barcode => '167Nabe0001'});
    ok (not($object1), "Item '167Nabe0001' deleted");
    my $object2 = Koha::Items->find({barcode => '167Nabe0002'});
    ok (not($object2), "Item '167Nabe0002' deleted");
    my $object3 = Koha::Biblios->find({title => 'I wish I met your mother', author => "Pertti Kurikka"});
    ok (not($object2), "Biblio 'I wish I met your mother' deleted");
};



########## CheckoutFactory subtests ##########
subtest 't::lib::TestObjects::CheckoutFactory' => \&testCheckoutFactory;
sub testCheckoutFactory {
    my $subtestContext = {};
    ##Create and Delete using dependencies in the $testContext instantiated in previous subtests.
    my $biblios = t::lib::TestObjects::BiblioFactory->createTestGroup([
                        {'biblio.title' => 'I wish I met your mother',
                         'biblio.author'   => 'Pertti Kurikka',
                         'biblio.copyrightdate' => '1960',
                         'biblioitems.isbn'     => '9519671580',
                         'biblioitems.itemtype' => 'BK',
                        },
                    ], 'biblioitems.isbn', undef, undef, $subtestContext);
    my $items = t::lib::TestObjects::ItemFactory->createTestGroup([
                        {biblionumber => $biblios->{9519671580}->{biblionumber},
                         barcode => '167Nabe0001',
                         homebranch   => 'CPL',
                         holdingbranch => 'CPL',
                         price     => '0.50',
                         replacementprice => '0.50',
                         itype => 'BK',
                         biblioisbn => '9519671580',
                         itemcallnumber => 'PK 84.2',
                        },
                        {biblionumber => $biblios->{9519671580}->{biblionumber},
                         barcode => '167Nabe0002',
                         homebranch   => 'CPL',
                         holdingbranch => 'FFL',
                         price     => '3.50',
                         replacementprice => '3.50',
                         itype => 'BK',
                         biblioisbn => '9519671580',
                         itemcallnumber => 'JK 84.2',
                        },
                    ], 'barcode', undef, undef, $subtestContext);
    my $objects = t::lib::TestObjects::CheckoutFactory->createTestGroup([
                    {
                        cardnumber        => '11A001',
                        barcode           => '167Nabe0001',
                        daysOverdue       => 7,
                        daysAgoCheckedout => 28,
                    },
                    {
                        cardnumber        => '11A002',
                        barcode           => '167Nabe0002',
                        daysOverdue       => -7,
                        daysAgoCheckedout => 14,
                        checkoutBranchRule => 'holdingbranch',
                    },
                    ], undef, undef, undef, undef);

    is($objects->{'11A001-167Nabe0001'}->branchcode,
       'CPL',
       "Checkout '11A001-167Nabe0001' checked out from the default context branch 'CPL'.");
    is($objects->{'11A002-167Nabe0002'}->branchcode,
       'FFL',
       "Checkout '11A002-167Nabe0002' checked out from the holdingbranch 'FFL'.");
    is(Koha::DateUtils::dt_from_string($objects->{'11A001-167Nabe0001'}->issuedate)->day(),
       DateTime->now(time_zone => C4::Context->tz())->subtract(days => '28')->day()
       , "Checkout '11A001-167Nabe0001', adjusted issuedates match.");
    is(Koha::DateUtils::dt_from_string($objects->{'11A002-167Nabe0002'}->date_due)->day(),
       DateTime->now(time_zone => C4::Context->tz())->subtract(days => '-7')->day()
       , "Checkout '11A002-167Nabe0002', adjusted date_dues match.");

    t::lib::TestObjects::CheckoutFactory->deleteTestGroup($objects);
    my $object1 = Koha::Checkouts->find({borrowernumber => $objects->{'11A001-167Nabe0001'}->borrowernumber,
                                         itemnumber => $objects->{'11A001-167Nabe0001'}->itemnumber});
    ok (not($object1), "Checkout '11A001-167Nabe0001' deleted");
    my $object2 = Koha::Checkouts->find({borrowernumber => $objects->{'11A002-167Nabe0002'}->borrowernumber,
                                         itemnumber => $objects->{'11A002-167Nabe0002'}->itemnumber});
    ok (not($object2), "Checkout '11A002-167Nabe0002' deleted");
};



########## LetterTemplateFactory subtests ##########
subtest 't::lib::TestObjects::LetterTemplateFactory' => \&testLetterTemplateFactory;
sub testLetterTemplateFactory {
    my $subtestContext = {};
    ##Create and Delete using dependencies in the $testContext instantiated in previous subtests.
    my $f = t::lib::TestObjects::LetterTemplateFactory->new();
    my $hashLT = {letter_id => 'circulation-ODUE1-CPL-print',
                module => 'circulation',
                code => 'ODUE1',
                branchcode => 'CPL',
                name => 'Notice1',
                is_html => undef,
                title => 'Notice1',
                message_transport_type => 'print',
                content => '<item>Barcode: <<items.barcode>>, bring it back!</item>',
            };
    my $objects = $f->createTestGroup([
                    $hashLT,
                    ], undef, undef, undef, undef);

    my $letterTemplate = Koha::LetterTemplates->find($hashLT);
    is($objects->{'circulation-ODUE1-CPL-print'}->name, $letterTemplate->name, "LetterTemplate 'circulation-ODUE1-CPL-print'");

    #Delete them
    $f->deleteTestGroup($objects);
    $letterTemplate = Koha::LetterTemplates->find($hashLT);
    ok(not(defined($letterTemplate)), "LetterTemplate 'circulation-ODUE1-CPL-print' deleted");
};



########## AtomicUpdateFactory subtests ##########
subtest 't::lib::TestObjects::AtomicUpdateFactory' => \&testAtomicUpdateFactory;
sub testAtomicUpdateFactory {
    my ($atomicUpdater, $atomicupdate);
    my $subtestContext = {};
    ##Create and Delete using dependencies in the $testContext instantiated in previous subtests.
    my $atomicupdates = t::lib::TestObjects::AtomicUpdateFactory->createTestGroup([
                            {'issue_id' => 'Bug10',
                             'filename' => 'Bug10-RavingRabbitsMayhem.pl',
                             'modification_time' => '2015-01-02 15:59:32',},
                            {'issue_id' => 'Bug11',
                             'filename' => 'Bug11-RancidSausages.perl',
                             'modification_time' => '2015-01-02 15:59:33',},
                            ],
                            undef, $subtestContext);
    $atomicUpdater = Koha::AtomicUpdater->new();
    $atomicupdate = $atomicUpdater->find({issue_id => $atomicupdates->{Bug10}->issue_id});
    is($atomicupdate->issue_id,
       'Bug10',
       "Bug10-RavingRabbitsMayhem created");
    $atomicupdate = $atomicUpdater->find({issue_id => $atomicupdates->{Bug11}->issue_id});
    is($atomicupdate->issue_id,
       'Bug11',
       "Bug11-RancidSausages created");

    t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);

    $atomicupdate = $atomicUpdater->find({issue_id => $atomicupdates->{Bug10}->issue_id});
    ok(not($atomicupdate),
       "Bug10-RavingRabbitsMayhem deleted");
    $atomicupdate = $atomicUpdater->find({issue_id => $atomicupdates->{Bug11}->issue_id});
    ok(not($atomicupdate),
       "Bug11-RancidSausages created");
};



########## SystemPreferenceFactory subtests ##########
subtest 't::lib::TestObjects::SystemPreferenceFactory' => \&testSystemPreferenceFactory;
sub testSystemPreferenceFactory {
    my $subtestContext = {};

    # take syspref 'opacuserlogin' and save its current value
    my $current_pref_value = C4::Context->preference("opacuserlogin");

    is($current_pref_value, $current_pref_value, "System Preference 'opacuserlogin' original value '".(($current_pref_value) ? $current_pref_value : 0)."'");

    # reverse the value for testing
    my $pref_new_value = !$current_pref_value || 0;

    my $objects = t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([
                    {preference => 'opacuserlogin',
                    value      => $pref_new_value # set the reversed value
                    },
                    ], undef, $subtestContext, undef, undef);

    is(C4::Context->preference("opacuserlogin"), $pref_new_value, "System Preference opacuserlogin reversed to '".(($pref_new_value) ? $pref_new_value:0)."'");

    # let's change it again to test that only the original preference value is saved
    $objects = t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([
            {preference => 'opacuserlogin',
             value      => 2 # set the reversed value
            },
            ], undef, $subtestContext, undef, undef);

    is(C4::Context->preference("opacuserlogin"), 2, "System Preference opacuserlogin set to '2'");

    #Delete them
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($subtestContext);
    is(C4::Context->preference("opacuserlogin"), $current_pref_value, "System Preference opacuserlogin restored to '".(($current_pref_value) ? $current_pref_value:0)."' after test group deletion");
};



########## Global test context subtests ##########
subtest 't::lib::TestObjects::ObjectFactory clearing global test context' => \&testGlobalSubtestContext;
sub testGlobalSubtestContext {
    my $object11A001 = Koha::Borrowers->find({cardnumber => '11A001'});
    ok ($object11A001, "Global Borrower '11A001' exists");
    my $object11A002 = Koha::Borrowers->find({cardnumber => '11A002'});
    ok ($object11A002, "Global Borrower '11A002' exists");

    my $object1 = Koha::Items->find({barcode => '167Nabe0001'});
    ok ($object1, "Global Item '167Nabe0001' exists");
    my $object2 = Koha::Items->find({barcode => '167Nabe0002'});
    ok ($object2, "Global Item '167Nabe0002' exists");
    my $object3 = Koha::Biblios->find({title => 'I wish I met your mother', author => "Pertti Kurikka"});
    ok ($object2, "Global Biblio 'I wish I met your mother' exists");

    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);

    $object11A001 = Koha::Borrowers->find({cardnumber => '11A001'});
    ok (not($object11A001), "Global Borrower '11A001' deleted");
    $object11A002 = Koha::Borrowers->find({cardnumber => '11A002'});
    ok (not($object11A002), "Global Borrower '11A002' deleted");

    $object1 = Koha::Items->find({barcode => '167Nabe0001'});
    ok (not($object1), "Global Item '167Nabe0001' deleted");
    $object2 = Koha::Items->find({barcode => '167Nabe0002'});
    ok (not($object2), "Global Item '167Nabe0002' deleted");
    $object3 = Koha::Biblios->find({title => 'I wish I met your mother', author => "Pertti Kurikka"});
    ok (not($object2), "Global Biblio 'I wish I met your mother' deleted");
};



done_testing();

1;
