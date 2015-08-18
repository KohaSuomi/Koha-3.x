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

use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::SystemPreferenceFactory;

##Setting up the test context
my $testContext = {};

my $password = '1234';
my $borrowerFactory = t::lib::TestObjects::BorrowerFactory->new();
my $borrowers = $borrowerFactory->createTestGroup([
            {firstname  => 'Testone',
             surname    => 'Testtwo',
             cardnumber => '1A01',
             branchcode => 'CPL',
             userid     => 'normal_user',
             address    => 'testi',
             city       => 'joensuu',
             zipcode    => '80100',
             password   => $password,
            },
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

my $systempreferences = t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([
            {preference => 'ValidateEmailAddress',
             value      => 1
            },
            {preference => 'ValidatePhoneNumber',
             value      => 'ipn',
            },
            {preference => 'TalkingTechItivaPhoneNotification',
             value      => 1
            },
            {preference => 'SMSSendDriver',
             value      => 'test'
            },
        ], undef, $testContext);

my $permissionManager = Koha::Auth::PermissionManager->new();
$permissionManager->grantPermissions($borrowers->{'superuberadmin'}, {superlibrarian => 'superlibrarian'});

eval {

    # staff client
    my $memberentry = t::lib::Page::Members::Memberentry->new({borrowernumber => $borrowers->{'superuberadmin'}->borrowernumber, op => 'modify', destination => 'circ', categorycode => 'PT'});
    # opac
    my $main = t::lib::Page::Opac::OpacMain->new({borrowernumber => $borrowers->{'superuberadmin'}->borrowernumber});

    # set valid contacts and check preferences checkboxes
    $memberentry->doPasswordLogin($borrowers->{'superuberadmin'}->userid(), $password)
    ->setEmail("valid\@email.com")
    ->checkPreferences(1, "email")
    ->setPhone("+3585012345678")
    ->checkPreferences(1, "phone")
    ->setSMSNumber("+3585012345678")
    ->checkPreferences(1, "sms")
    ->submitForm(1) # expecting success
    ->navigateToDetails()
    # make sure everything is now checked on moremember.pl details page
    ->checkMessagingPreferencesSet(1, "email", "sms", "phone");

    $main # check that they are also checked in OPAC
    ->doPasswordLogin($borrowers->{'superuberadmin'}->userid(), $password)
    ->navigateYourMessaging()
    ->checkMessagingPreferencesSet(1, "email", "sms", "phone");

    # go to edit patron and set invalid contacts.
    $memberentry
    ->navigateEditPatron()
    ->setEmail("invalidemail.com")
    ->checkPreferences(0, "email")
    ->setPhone("+3585012asd345678")
    ->checkPreferences(0, "phone")
    ->setSMSNumber("+358501asd2345678")
    ->checkPreferences(0, "sms")
    # check messaging preferences: they should be unchecked
    ->checkMessagingPreferencesSet(0, "email", "sms", "phone")
    ->submitForm(0) # also confirm that we cant submit the preferences
    ->navigateToDetails()

    # go to library use and just simply submit the form without any changes
    ->navigateToLibraryUseEdit()
    ->submitForm(1)
    # all the preferences should be still set
    ->navigateToDetails()
    ->checkMessagingPreferencesSet(1, "email", "sms", "phone")

    # go to smsnumber edit and make sure everything is checked
    ->navigateToSMSnumberEdit()
    ->checkMessagingPreferencesSet(1, "email", "sms", "phone")
    ->submitForm(1)
    ->navigateToDetails()
    ->checkMessagingPreferencesSet(1, "email", "sms", "phone")

    # go to patron information edit and clear email and phone
    ->navigateToPatronInformationEdit()
    ->clearMessagingContactFields("email", "phone")
    ->submitForm(1)
    ->navigateToDetails()
    # this should remove our messaging preferences for phone and email
    ->checkMessagingPreferencesSet(0, "email", "phone")
    ->checkMessagingPreferencesSet(1, "sms"); # ... but not for sms (it's still set)

    $main # check the preferences also from OPAC
    ->navigateYourMessaging()
    ->checkMessagingPreferencesSet(0, "email", "phone")
    ->checkMessagingPreferencesSet(1, "sms");

    # go to smsnumber edit and see that email and phone are disabled
    $memberentry
    ->navigateToSMSnumberEdit()
    ->checkMessagingPreferencesSet(0, "email", "phone")
    ->clearMessagingContactFields("SMSnumber") # uncheck all sms preferences
    ->submitForm(1)
    ->navigateToDetails()
    ->checkMessagingPreferencesSet(0, "email", "phone", "sms");

    $main # check the preferences also from OPAC
    ->navigateYourMessaging()
    ->checkMessagingPreferencesSet(0, "email", "phone", "sms");

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
