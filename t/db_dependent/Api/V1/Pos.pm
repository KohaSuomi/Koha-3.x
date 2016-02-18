package t::db_dependent::Api::V1::Pos;

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
use Encode;

use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::FinesFactory;
use t::lib::TestObjects::SystemPreferenceFactory;

use C4::Members;
use C4::Context;
use C4::OPLIB::CPUIntegration;
use Digest::SHA;

sub postcpu_n_report404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath(77747777777);

    # Load the secret key - we need it to generate the checksum
    my $secretKey = C4::Context->config('pos')->{'CPU'}->{'secretKey'};

    my $post;
    $post->{Source} = "KOHA";
    $post->{Id} = "77747777777";
    $post->{Status} = 1;
    $post->{Reference} = "77747777777";

    # Calculate checksum
    my $data = $post->{Source}."&".$post->{Id}."&".$post->{Status}."&".$post->{Reference}."&".$secretKey;
    my $hash = Digest::SHA::sha256_hex($data);

    # Add checksum to POST parameters
    $post->{Hash} = $hash;

    # Post it
    $driver->post_ok($path => {Accept => 'text/json'} => json => $post);

    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub postcpu_n_report400 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath(77747777777);

    # 400 will be given because the POST has an invalid
    # SHA256 checksum (here we give none at all)
    $driver->post_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(400);
}

sub postcpu_n_report200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();

    # Set default item number and activate POS integration
    my $systempreferences = t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([
            {preference => 'POSIntegration',
             value      => 'cpu',
            },
            {preference => 'cpuitemnumbers',
             value      => '
             CPL:
               Default: 0000
             ',
            },
        ], undef, $testContext);

    # Create a new fine for the Borrower
    my $finesfactory = t::lib::TestObjects::FinesFactory->createTestGroup({
        amount => 10.0,
        cardnumber => '1A23',
        accounttype => 'FU',
        note => 'unique identifier',
    }, undef, $testContext);

    # Create payment_transaction.
    my $payment = C4::OPLIB::CPUIntegration::InitializePayment({
        borrowernumber => Koha::Borrowers->find({ cardnumber => '1A23' })->borrowernumber,
        office => 100,
        total_paid => 10.0,
        selected => []
    });

    # Set the path to payment id
    my $path = $restTest->get_routePath($payment->{Id});

    # Load the secret key - we need it to generate the checksum
    my $secretKey = C4::Context->config('pos')->{'CPU'}->{'secretKey'};

    # Generate a HASH that simulates CPU response
    my $post;
    $post->{Source} = "KOHA";
    $post->{Id} = $payment->{Id};
    $post->{Status} = 1;
    $post->{Reference} = $payment->{Id};

    # Calculate checksum for the response
    my $data = $post->{Source}."&".$post->{Id}."&".$post->{Status}."&".$post->{Reference}."&".$secretKey;
    my $hash = Digest::SHA::sha256_hex($data);

    # Add checksum to CPU response
    $post->{Hash} = $hash;

    # Post it
    $driver->post_ok($path => {Accept => 'text/json'} => json => $post);

    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
}

sub getcpu_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath(77747777777);

    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub getcpu_n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();

        # Set default item number and activate POS integration
    my $systempreferences = t::lib::TestObjects::SystemPreferenceFactory->createTestGroup([
            {preference => 'POSIntegration',
             value      => 'cpu',
            },
            {preference => 'cpuitemnumbers',
             value      => '
             CPL:
               Default: 0000
             ',
            },
        ], undef, $testContext);

    # Create a new fine for the Borrower
    my $finesfactory = t::lib::TestObjects::FinesFactory->createTestGroup({
        amount => 10.0,
        cardnumber => '1A23',
        accounttype => 'FU',
        note => 'unique identifier',
    }, undef, $testContext);

    # Create payment
    my $payment = C4::OPLIB::CPUIntegration::InitializePayment({
        borrowernumber => Koha::Borrowers->find({ cardnumber => '1A23' })->borrowernumber,
        office => 100,
        total_paid => 10.0,
        selected => []
    });

    my $path = $restTest->get_routePath($payment->{Id});
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
}

1;