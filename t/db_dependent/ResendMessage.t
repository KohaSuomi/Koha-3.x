#!/usr/bin/env perl

# Copyright 2015 Vaara-kirjastot
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
             smsalertnumber => '99999999999912007',
             zipcode    => '80100',
             password   => $password,
            },
        ], undef, $testContext);
my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup([
            {subject => "Test pending",
             content => "Tessst content",
             cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
             message_transport_type => 'sms',
             from_address => 'A001@example.com',
            },
            {subject => "Test sent",
             content => "Tessst content",
             cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
             message_transport_type => 'sms',
             from_address => 'A002@example.com',
            },
            {subject => "Test failed",
             content => "Tessst content",
             cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
             message_transport_type => 'sms',
             to_address   => '',
             from_address => 'A003@example.com',
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
$permissionManager->grantPermissions($borrowers->{'superuberadmin'}, {catalogue => 'staff_login', borrowers => 'view_borrowers'});

eval {

    # staff client
    my $notices = t::lib::Page::Members::Notices->new({borrowernumber => $borrowers->{'superuberadmin'}->borrowernumber});

    setMessageStatus($messages->{'A001@example.com'}->{message_id}, "pending");
    setMessageStatus($messages->{'A002@example.com'}->{message_id}, "sent");
    setMessageStatus($messages->{'A003@example.com'}->{message_id}, "failed");

    # then, login to intranet
    $notices->doPasswordLogin($borrowers->{'superuberadmin'}->userid(), $password)
    ->openNotice("Test pending")
    ->openNotice("Test sent")
    ->openNotice("Test failed")
    ->resendMessage("Test pending", 0) #pending cannot be resent
    ->resendMessage("Test sent", 0) # --these two should fail because
    ->resendMessage("Test failed", 0); # of missing permissions--

    # add permission and refresh page
    $permissionManager->grantPermissions($borrowers->{'superuberadmin'}, {messages => 'resend_message'});
    $notices
    ->navigateToNotices() # refresh page and make sure everything is pending
    ->openNotice("Test pending")
    ->openNotice("Test sent")
    ->openNotice("Test failed")
    ->resendMessage("Test pending", 0) # pending cannot be resent
    ->resendMessage("Test sent", 1) # --these two should now
    ->resendMessage("Test failed", 1) # resend successfully--
    ->navigateToNotices()
    ->getTextInColumnAtRow("pending", { row => 1, column => 3 })
    ->getTextInColumnAtRow("pending", { row => 2, column => 3 })
    ->getTextInColumnAtRow("pending", { row => 3, column => 3 });
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

sub setMessageStatus {
    my ($message_id, $status) = @_;
    return C4::Letters::UpdateQueuedMessage({ message_id => $message_id, status => $status } );
}