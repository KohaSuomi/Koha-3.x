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
        ], undef, $testContext);

my $permissionManager = Koha::Auth::PermissionManager->new();
$permissionManager->grantPermissions($borrowers->{'superuberadmin'}, {superlibrarian => 'superlibrarian'});

eval {
    OpacValidations();
    StaffValidations();
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
sub setValidationsOff {
    C4::Context->set_preference('ValidateEmailAddress', 0);
    C4::Context->set_preference('ValidatePhoneNumber', 'OFF');
}
sub setValidationsOn {
    C4::Context->set_preference('ValidateEmailAddress', 1);
    C4::Context->set_preference('ValidatePhoneNumber', 'ipn');
}

sub OpacValidations {
    my $main = t::lib::Page::Opac::OpacMain->new({borrowernumber => $borrowers->{'superuberadmin'}->borrowernumber});

    ok (0, "Email validation is OFF!") if (C4::Context->preference('ValidateEmailAddress') == 0);
    ok (0, "Phone validation is OFF") if C4::Context->preference('ValidatePhoneNumber') eq "OFF";
    $main
    ->doPasswordLogin($borrowers->{'superuberadmin'}->userid(), $password)
    ->navigateYourPersonalDetails()
    ->setEmail("valid\@email.com") # test valid email
    ->submitForm(1) # expecting success
    ->navigateYourPersonalDetails()
    ->setEmail("invalidemail") # test invalid email
    ->submitForm(0) # expecting error
    ->navigateYourPersonalDetails()
    ->setPhone("+3585012345667") # test valid phone number
    ->submitForm(1) # expecting success
    ->navigateYourPersonalDetails()
    ->setPhone("1234phone56789") # test invalid phone number
    ->submitForm(0); # expecting error

    print "--Setting validations off--\n";
    setValidationsOff(); # set validations off from system prefs
    #then test validations again
    ok (0, "Email validation is ON!") if (C4::Context->preference('ValidateEmailAddress') == 1);
    ok (0, "Phone validation is ON!") if C4::Context->preference('ValidatePhoneNumber') ne "OFF";

    $main
    ->navigateYourPersonalDetails()
    ->setEmail("invalidemail_validations_off") # test invalid email
    ->submitForm(1) # expecting success
    ->navigateYourPersonalDetails()
    ->setPhone("1234phone56789_validations_off") # test invalid phone number
    ->submitForm(1); # expecting success

    setValidationsOn();
}

sub StaffValidations {
    my $memberentry = t::lib::Page::Members::Memberentry->new({borrowernumber => $borrowers->{'superuberadmin'}->borrowernumber, op => 'modify', destination => 'circ', categorycode => 'PT'});

    ok (0, "Email validation is OFF!") if (C4::Context->preference('ValidateEmailAddress') == 0);
    ok (0, "Phone validation is OFF") if C4::Context->preference('ValidatePhoneNumber') eq "OFF";

    $memberentry
    ->doPasswordLogin($borrowers->{'superuberadmin'}->userid(), $password)
    ->setEmail("valid\@email.com") # test valid email
    ->submitForm(1) # expecting success
    ->navigateEditPatron()
    ->setEmail("invalidemail") # test invalid email
    ->submitForm(0) # expecting error
    ->setEmail("")
    ->setPhone("+3585012345667") # test valid phone number
    ->submitForm(1) # expecting success
    ->navigateEditPatron()
    ->setPhone("1234phone56789") # test invalid phone number
    ->submitForm(0); # expecting error

    print "--Setting validations off--\n";
    setValidationsOff(); # set validations off from system prefs
    #then test validations again

    ok (0, "Email validation is ON!") if (C4::Context->preference('ValidateEmailAddress') == 1);
    ok (0, "Phone validation is ON!") if C4::Context->preference('ValidatePhoneNumber') ne "OFF";

    $memberentry
    ->setPhone("") # refreshing
    ->setEmail("") # the
    ->submitForm(1)    # page
    ->navigateEditPatron()
    ->setEmail("invalidemail_validations_off") # test invalid email
    ->submitForm(1) # expecting success
    ->navigateEditPatron()
    ->setPhone("1234phone56789_validations_off") # test invalid phone number
    ->submitForm(1); # expecting success

    setValidationsOn();
}