package t::db_dependent::Api::V1::Messages;

use Modern::Perl;
use Test::More;

use t::lib::TestObjects::ObjectFactory;
use t::lib::TestObjects::MessageQueueFactory;

use C4::Letters;

sub get200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    #Create the test context.
    my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->{'_result'}->{'_column_data'}->{cardnumber},
                            message_transport_type => 'sms',
                            from_address => '11A001@example.com',
                        }, undef, $testContext, undef, undef);

    my $messagenumber = $messages->{'11A001@example.com'}->{message_id};

    $driver->get_ok($path => {Accept => 'text/json'});
    $driver->status_is(200);

    $driver->json_has("message_id", "Message id in JSON.");

    return 1;
}

sub get404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath();
    my $testContext = $restTest->get_testContext();

    $driver->get_ok($path => {Accept => 'text/json'});
    $driver->status_is(404);

    return 1;
}

sub get_n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    #Create the test context.
    my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->{'_result'}->{'_column_data'}->{cardnumber},
                            message_transport_type => 'sms',
                            from_address => '11A002@example.com',
                        }, undef, $testContext, undef, undef);

    my $messagenumber = $messages->{'11A002@example.com'}->{message_id};
    $path =~ s/\{messagenumber\}/$messagenumber/;

    $driver->get_ok($path => {Accept => 'text/json'});
    $driver->status_is(200);

    $driver->json_is('/message_id' => $messagenumber, "Message $messagenumber found!");

    return 1;
}

sub get_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath();

    $path =~ s/\{messagenumber\}/12349329003007/;
    $driver->get_ok($path => {Accept => 'text/json'});
    $driver->status_is(404);

    return 1;
}

sub post201 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath();
    my $activeUser = $restTest->get_activeBorrower();

    $driver->post_ok($path => {Accept => 'text/json'} => json => {
            subject => "hello",
            content => "world",
            message_transport_type => "email",
            borrowernumber => $activeUser->{'_result'}->{'_column_data'}->{borrowernumber},
        });
    $driver->status_is(201);

    # dequeue the message right after so that get 404 tests will work
    my $json = $driver->tx->res->json();
    C4::Letters::DequeueLetter({ message_id => $json->{message_id} });

    return 1;
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
    my $path = $restTest->get_routePath();

    #Create the test context.
    my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->{'_result'}->{'_column_data'}->{cardnumber},
                            message_transport_type => 'sms',
                            from_address => '11A003@example.com',
                        }, undef, $testContext, undef, undef);

    # send and get the message
    C4::Letters::SendQueuedMessages();
    my $message = C4::Letters::GetMessage($messages->{'11A003@example.com'}->{message_id});
    my $messagenumber = $messages->{'11A003@example.com'}->{message_id};
    $path =~ s/\{messagenumber\}/$messagenumber/;

    # sms status should be failed
    is($message->{status}, "failed", "Send failed correctly");

    $driver->post_ok($path => {Accept => 'text/json'});
    $driver->status_is(204);

    $message = C4::Letters::GetMessage($messages->{'11A003@example.com'}->{message_id});
    is($message->{status}, "pending", "Resend set message status to pending correctly");

    return 1;
}

sub post_n_resend404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath();

    $path =~ s/\{messagenumber\}/12349329003007/;
    $driver->post_ok($path => {Accept => 'text/json'});
    $driver->status_is(404);

    return 1;
}

sub put_n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    #Create the test context.
    my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->{'_result'}->{'_column_data'}->{cardnumber},
                            message_transport_type => 'sms',
                            from_address => '11A003@example.com',
                        }, undef, $testContext, undef, undef);

    my $messagenumber = $messages->{'11A003@example.com'}->{message_id};
    $path =~ s/\{messagenumber\}/$messagenumber/;

    $driver->put_ok($path => {Accept => 'text/json'} => json => {
            subject => "hello",
            content => "world",
        });
    $driver->status_is(200);

    my $json = $driver->tx->res->json();
    is($json->{subject}, "hello", "Put updated message subject correctly");

    return 1;
}

sub put_n_400 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    $path =~ s/\{messagenumber\}/12349329003007/;
    $driver->put_ok($path => {Accept => 'text/json'} => json => {
            message_transport_type => "hello", #invalid transport type
        });
    $driver->status_is(400);

    return 1;
}

sub put_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath();

    $path =~ s/\{messagenumber\}/12349329003007/;
    $driver->put_ok($path => {Accept => 'text/json'});
    $driver->status_is(404);

    return 1;
}

sub delete_n_204 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    #Create the test context.
    my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->{'_result'}->{'_column_data'}->{cardnumber},
                            message_transport_type => 'sms',
                            from_address => '11A004@example.com',
                        }, undef, $testContext, undef, undef);

    my $messagenumber = $messages->{'11A004@example.com'}->{message_id};
    $path =~ s/\{messagenumber\}/$messagenumber/;

    $driver->delete_ok($path => {Accept => 'text/json'});
    $driver->status_is(204);

    return 1;
}

sub delete_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $path = $restTest->get_routePath();

    $path =~ s/\{messagenumber\}/12349329003007/;
    $driver->delete_ok($path => {Accept => 'text/json'});
    $driver->status_is(404);

    return 1;
}

sub post_n_reportlabyrintti404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    $path =~ s/\{messagenumber\}/12334893298007/;
    $driver->post_ok(
                    $path => { Accept => 'application/x-www-form-urlencoded'} =>
                    form => {
                        status => "OK",
                        message => "Message delivery succesful",
                    });
    $driver->status_is(404);

    return 1;
}

sub post_n_reportlabyrintti200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext();
    my $activeUser = $restTest->get_activeBorrower();
    my $path = $restTest->get_routePath();

    #Create the test context.
    my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup(
                        {
                            subject => "The quick brown fox",
                            content => "Jumps over the lazy dog.",
                            cardnumber => $activeUser->{'_result'}->{'_column_data'}->{cardnumber},
                            message_transport_type => 'sms',
                            from_address => '11A001@example.com',
                        }, undef, $testContext, undef, undef);

    my $messagenumber = $messages->{'11A001@example.com'}->{message_id};
    $path =~ s/\{messagenumber\}/$messagenumber/;
    $driver->post_ok(
                    $path => { Accept => 'application/x-www-form-urlencoded'} =>
                    form => {
                        status => "ERROR",
                        message => "Test error delivery note",
                    }
            );
    $driver->status_is(200);
    my $message = C4::Letters::GetMessage($messagenumber);
    is($message->{delivery_note}, "Test error delivery note", "Delivery note for failed SMS received successfully.");

    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
    return 1;
}

1;