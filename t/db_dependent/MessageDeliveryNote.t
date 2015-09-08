#!/usr/bin/env perl

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
$ENV{KOHA_PAGEOBJECT_DEBUG} = 1;
use Modern::Perl;

use Test::More;
use Try::Tiny; #Even Selenium::Remote::Driver uses Try::Tiny :)

use Koha::Auth::PermissionManager;

use t::lib::Page::Mainpage;
use t::lib::Page::Opac::OpacMain;
use t::lib::Page::Opac::OpacMemberentry;
use t::lib::Page::Members::Memberentry;
use t::lib::Page::Members::Moremember;
use t::lib::Page::Members::Notices;

use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::MessageQueueFactory;
use t::lib::TestObjects::SystemPreferenceFactory;

use C4::Context;
use C4::Members;

##Setting up the test context
my $testContext = {};

my $password = '1234';
my $invalidBorrowerNumber = '000';
my $borrowerFactory = t::lib::TestObjects::BorrowerFactory->new();
my $borrowers = $borrowerFactory->createTestGroup([
            {firstname  => 'Testthree',
             surname    => 'Testfour',
             cardnumber => 'superuberadmin',
             branchcode => 'CPL',
             userid     => 'god',
             address    => 'testi',
             city       => 'joensuu',
             zipcode    => '80100',
             password   => $password,
            },
        ], undef, $testContext);
my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup([
            {letter => {
                title => "Test title",
                content => "Tessst content",
                },
             cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
             message_transport_type => 'sms',
             from_address => 'A001@example.com',
            },
            {letter => {
                title => "Test title",
                content => "Tessst content",
                },
             cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
             message_transport_type => 'sms',
             from_address => 'A002@example.com',
            },
            {letter => {
                title => "Test title",
                content => "Tessst content",
                },
             cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
             message_transport_type => 'email',
             to_address   => '',
             from_address => 'B001@example.com',
            },
            {letter => {
                title => "Test title",
                content => "Tessst content",
                },
             cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
             message_transport_type => 'email',
             to_address   => 'nobody@example.com',
             from_address => 'B002@example.com',
            },
            {letter => {
                title => "INVALID USER",
                content => "INVALID USER",
                },
             cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
             message_transport_type => 'email',
             to_address   => '',
             from_address => 'B003@example.com',
            },
        ], undef, $testContext);
my $systempreferences = t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([
            {preference => 'SMSSendDriver',
             value      => 'nonexistentdriver'
            },
            {
             preference => 'EnhancedMessagingPreferences',
             value      => '1'
            }
        ], undef, $testContext);

my $permissionManager = Koha::Auth::PermissionManager->new();
$permissionManager->grantPermissions($borrowers->{'superuberadmin'}, {superlibrarian => 'superlibrarian'});

eval {

    # staff client
    my $notices = t::lib::Page::Members::Notices->new({borrowernumber => $borrowers->{'superuberadmin'}->borrowernumber});

    # let's send the messages

    # first, send one email message with invalid borrower number
    $messages->{'B003@example.com'}->{borrowernumber} = $invalidBorrowerNumber;
    C4::Letters::_send_message_by_email($messages->{'B003@example.com'});

    # the rest should produce errors automatically without our modificaitons
    C4::Letters::SendQueuedMessages();

    # then, login to intranet
    $notices->doPasswordLogin($borrowers->{'superuberadmin'}->userid(), $password);

    # test delivery notes for SMS messaging
    DoSMSTests($notices);
    # check delivery notes for email messaging
    CheckEmailMessages($notices);

};
if ($@) { #Catch all leaking errors and gracefully terminate.
    warn $@;
    tearDown();
    exit 1;
}

##All tests done, tear down test context
tearDown();
done_testing;

sub tearDown {
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
}








######################################################
    ###  STARTING TEST IMPLEMENTATIONS         ###
######################################################

sub DoSMSTests {
    my ($notices) = @_;

    # login and check that our table is displayed correctly
    $notices->
    hasDeliveryNoteColumnInNoticesTable()->
    hasTextInTableCell("Missing SMS number");

    # now let's give the user a SMS number so we proceed to next step of failure
    ModMember( borrowernumber => $borrowers->{superuberadmin}->borrowernumber,
                            smsalertnumber => 'just_some_number' );

    # set first to sent and second to pending to check "duplicate" (Letters::_is_duplicate())
    setMessageStatus($messages->{'A001@example.com'}->{message_id}, "sent");
    setMessageStatus($messages->{'A002@example.com'}->{message_id}, "pending");

    C4::Letters::SendQueuedMessages();
    # A002 should go into failed: message is duplicate status

    # set A001 back to pending to check that we get no reply from driver
    setMessageStatus($messages->{'A001@example.com'}->{message_id}, "pending");

    # let's send the message and check for delivery note, we should get a warning
    # for non-installed driver.
    C4::Letters::SendQueuedMessages();

    $notices->navigateToNotices()->
    hasTextInTableCell("Message is duplicate")->
    hasTextInTableCell("No notes from SMS driver");
}

sub CheckEmailMessages {
    my ($notices) = @_;

    $notices->
    hasTextInTableCell("Unable to find an email address")->
    hasTextInTableCell("Invalid borrowernumber")->
    hasTextInTableCell("Connection refused"); #sendmail should also fail
}
sub setMessageStatus {
    my ($message_id, $status) = @_;
    my $dbh = C4::Context->dbh;

    my $sth = $dbh->prepare("UPDATE message_queue SET status=?, delivery_note='' WHERE message_id=?");
    my $result = $sth->execute($status, $message_id);

    return $result;
}