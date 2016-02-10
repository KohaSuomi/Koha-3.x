package t::db_dependent::Api::V1::Messages;

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
use t::lib::TestObjects::MessageQueueFactory;

use C4::Letters;

sub get200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    my ($messages, $messagenumber);

    #Create the test context.
    $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup([
                        {
                            subject => Encode::decode_utf8("Sotilaat!"),
                            content => Encode::decode_utf8("Olen taistellut monilla tanterilla, mutta en vielä nähnyt vertaisianne sotureita. Olen ylpeä teistä kuin olisitte omia lapsiani, yhtä ylpeä tuntureitten miehestä Pohjolassa kuin Pohjanmaan lakeuksien, Karjalan metsien, Savon kumpujen, Hämeen ja Satakunnan viljavien vainioitten, Uudenmaan ja Varsinais-Suomen lauheitten lehtojen pojasta. Olen yhtä ylpeä uhrista, jonka tarjoaa köyhän majan poika siinä kuin rikaskin."),
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A000@example.com',
                        },
                        {
                            subject => Encode::decode_utf8("Yli 15.000 teistä, jotka lähditte kentälle, ei enää näe kotejansa"),
                            content => Encode::decode_utf8("Ja kuinka monet ovatkaan ainiaaksi menettäneet työkykynsä. Mutta te olette myös jakaneet kovia iskuja, ja kun nyt parisataatuhatta vihollistamme lepää hangessa ja tuijottaa särkynein katsein tähtitaivaallemme, ei syy ole teidän. Te ette heitä vihanneet ja tahtoneet heille pahaa, vaan seurasitte sodan ankaraa lakia, tappaa tai kuolla itse."),
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A001@example.com',
                        },
                        {
                            subject => Encode::decode_utf8("Teidän sankaritekonne ovat herättäneet ihailua yli maiden"),
                            content => Encode::decode_utf8("Mutta kolme ja puoli kuukautta kestäneen sodan jälkeen olemme edelleen melkein yksin. Emme ole saaneet enempää kuin 2 vahvistettua pataljoonaa tykistöineen ja lentokoneineen ulkomaista apua rintamillemme, joilla omat miehemme taistelussa yötä päivää ilman vaihdon mahdollisuutta ovat saaneet ottaa vastaan yhä uusien vihollisvoimien hyökkäykset ponnistaen ruumiilliset ja henkiset voimansa rajattomiin asti."),
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A002@example.com',
                        }
                    ], undef, $testContext, undef, undef);

    $driver->get_ok($path => {Accept => 'text/json'});
    $driver->status_is(200);

    $driver->json_is("/0/message_id", $messages->{'11A000@example.com'}->{message_id}, "Message0: message_id in JSON.");
    $driver->json_is("/0/subject",    $messages->{'11A000@example.com'}->{subject},    "Message0: subject in JSON.");
    $driver->json_is("/1/message_id", $messages->{'11A001@example.com'}->{message_id}, "Message1: message_id in JSON.");
    $driver->json_is("/1/subject",    $messages->{'11A001@example.com'}->{subject},    "Message1: subject in JSON.");
    $driver->json_is("/2/message_id", $messages->{'11A002@example.com'}->{message_id}, "Message2: message_id in JSON.");
    $driver->json_is("/2/subject",    $messages->{'11A002@example.com'}->{subject},    "Message2: subject in JSON.");
}

sub get404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath();
    my $testContext = $restTest->get_testContext();

    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub get_n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $message, $messagenumber);

    #Create the test context.
    $message = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A002@example.com',
                        }, undef, $testContext);

    $messagenumber = $message->{message_id};
    $path = $restTest->get_routePath($messagenumber);
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $driver->json_is('/message_id' => $messagenumber, "Message found!");
}

sub get_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath(12349329003007);

    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub post201 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    my ($message, $messagenumber);

    #Create a complete MessageQueue
    $message = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => Encode::decode_utf8("Te ette ole tahtoneet sotaa"),
                            content => Encode::decode_utf8("Te rakastitte rauhaa, työtä ja kehitystä, mutta teidät pakotettiin taisteluun, jossa olette tehneet suurtöitä, tekoja, jotka vuosisatoja tulevat loistamaan historian lehdillä."),
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A002@example.com',
                        }, undef, $testContext);
    $messagenumber = $message->{message_id};

    #Delete it from DB and imagine it is a brand new MessageQueue
    C4::Letters::DequeueLetter( {message_id => $messagenumber} );
    delete $message->{message_id};
    delete $message->{time_queued};

    $driver->post_ok($path => {Accept => 'text/json'} => json => C4::Letters::swaggerize($message));
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(201);

    #Redefine the message_id for the created MessageQueue which has been put to the $testContext by the TestObjectFactory. Thus autoremoval can occurr.

    my $json = $driver->tx->res->json();
    $message->{message_id} = $json->{message_id};
}

sub post400 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath();
    my $activeUser = $restTest->get_activeBorrower();

    #post with missing mandatory parameters
    $driver->post_ok($path => {Accept => 'text/json'} => json => {
            subject => "hello"
        });
    $driver->status_is(400);

    return 1;
}

sub post_n_resend204 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $message, $messageInDB, $messagenumber);

    #Create the test context.
    $message = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A003@example.com',
                        }, undef, $testContext, undef, undef);
    $messagenumber = $message->{message_id};

    # send and get the message
    C4::Letters::SendQueuedMessages();
    $messageInDB = C4::Letters::GetMessage($messagenumber);
    $path = $restTest->get_routePath($messagenumber);

    # sms status should be failed
    is($messageInDB->{status}, "failed", "Send failed correctly");

    $driver->post_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(204);

    $message = C4::Letters::GetMessage($messagenumber);
    is($message->{status}, "pending", "Resend set message status to pending correctly");
}

sub post_n_resend404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath(12349329003007);

    $driver->post_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub put_n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $message, $messagenumber, $messageInDB, $json);

    #Create the test context.
    $message = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A003@example.com',
                        }, undef, $testContext);

    $messagenumber = $message->{message_id};
    $path = $restTest->get_routePath($messagenumber);

    $message->{subject} = 'hello world';
    $driver->put_ok($path => {Accept => 'text/json'} => json => C4::Letters::swaggerize($message));
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    $json = $driver->tx->res->json();
    is($json->{subject}, "hello world", "Put updated message subject correctly");

    #Check if the return values was actually persisted
    $messageInDB = C4::Letters::GetMessage($messagenumber);
    is($messageInDB->{subject}, "hello world", "Updated message subject persisted to DB");
}

sub put_n_400 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();


    my $path = $restTest->get_routePath(12349329003007);
    $driver->put_ok($path => {Accept => 'text/json'} => json => {
            message_transport_type => "hello", #invalid transport type
        });
    $driver->status_is(400);
}

sub put_n_404 {
    my ($class, $restTest, $driver) = @_;

    my $path = $restTest->get_routePath(12349329003007);
    $driver->put_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub delete_n_204 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $message, $messagenumber);

    #Create the test context.
    $message = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A004@example.com',
                        }, undef, $testContext, undef, undef);
    $messagenumber = $message->{message_id};
    $path = $restTest->get_routePath($messagenumber);

    $driver->delete_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(204);
}

sub delete_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath(12349329003007);

    $driver->delete_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub post_n_reportlabyrintti404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath(12334893298007);

    $driver->post_ok(
                    $path => { Accept => 'application/x-www-form-urlencoded'} =>
                    form => {
                        status => "OK",
                        message => "Message delivery succesful",
                    });
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);
}

sub post_n_reportlabyrintti200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $message, $messagenumber, $messageInDB);

    #Create the test context.
    $message = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->cardnumber,
                            message_transport_type => 'sms',
                            from_address => '11A001@example.com',
                        }, undef, $testContext, undef, undef);

    $messagenumber = $message->{message_id};
    $path = $restTest->get_routePath($messagenumber);
    $driver->post_ok(
                    $path => { Accept => 'application/x-www-form-urlencoded'} =>
                    form => {
                        status => "ERROR",
                        message => "Test error delivery note",
                    }
            );
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);
    $messageInDB = C4::Letters::GetMessage($messagenumber);
    is($messageInDB->{delivery_note}, "Test error delivery note", "Delivery note for failed SMS received successfully.");
}

1;