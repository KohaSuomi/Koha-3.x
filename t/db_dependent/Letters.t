#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright (C) 2013 Equinox Software, Inc.
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

use Test::More tests => 16;
use Test::MockModule;
use Test::Warn;

use C4::Context;
use C4::Letters;
use C4::Members;
use Koha::Exception::ConnectionFailed;

my $c4sms = new Test::MockModule('C4::SMS');
$c4sms->mock(
    'driver' =>
    sub {
        warn "Fake SMS driver";
        return "Example::ExceptionExample";
    }
);

my $dbh = C4::Context->dbh;

# Start transaction
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

$dbh->do(q|DELETE FROM letter|);
$dbh->do(q|DELETE FROM message_queue|);
$dbh->do(q|DELETE FROM message_transport_types|);

my $borrowernumber = AddMember(
    firstname    => 'Jane',
    surname      => 'Smith',
    categorycode => 'PT',
    branchcode   => 'CPL',
);

$dbh->do(q|
    INSERT INTO message_transport_types( message_transport_type ) VALUES ('email'), ('phone'), ('print'), ('sms')
|);

my $mtts = C4::Letters::GetMessageTransportTypes();
is_deeply( $mtts, ['email', 'phone', 'print', 'sms'], 'GetMessageTransportTypes returns all values' );

my $message_id = C4::Letters::EnqueueLetter({
    borrowernumber         => $borrowernumber,
    message_transport_type => 'sms',
    to_address             => 'to@example.com',
    from_address           => 'from@example.com',
    letter => {
        content      => 'a message',
        title        => 'message title',
        metadata     => 'metadata',
        code         => 'TEST_MESSAGE',
        content_type => 'text/plain',
    },
});

ok(defined $message_id && $message_id > 0, 'new message successfully queued');

my $messages_processed = C4::Letters::SendQueuedMessages();
is($messages_processed, 1, 'all queued messages processed');

my $messages = C4::Letters::GetQueuedMessages({ borrowernumber => $borrowernumber });
is(scalar(@$messages), 1, 'one message stored for the borrower');

is(
    $messages->[0]->{status},
    'failed',
    'message marked failed if tried to send SMS message for borrower with no smsalertnumber set (bug 11208)'
);

# ResendMessage
my $resent = C4::Letters::ResendMessage($messages->[0]->{message_id});
my $message = C4::Letters::GetMessage( $messages->[0]->{message_id});
is( $resent, 1, 'The message should have been resent' );
is($message->{status},'pending', 'ResendMessage sets status to pending correctly (bug 12426)');
$resent = C4::Letters::ResendMessage($messages->[0]->{message_id});
is( $resent, 0, 'The message should not have been resent again' );
$resent = C4::Letters::ResendMessage();
is( $resent, undef, 'ResendMessage should return undef if not message_id given' );

# UpdateQueuedMessage
is(C4::Letters::UpdateQueuedMessage({ message_id => $messages->[0]->{message_id}, content => "changed content" } ), 1, "Message updated correctly");
$messages = C4::Letters::GetQueuedMessages();
is($messages->[0]->{content}, "changed content", "Message content was changed correctly");

# Test connectivity Exception (Bug 14791)
ModMember(borrowernumber => $borrowernumber, smsalertnumber => "+1234567890");
warning_is { $messages_processed = C4::Letters::SendQueuedMessages(); }
    "Fake SMS driver",
   "SMS sent using the mocked SMS::Send driver subroutine send_sms";
$messages = C4::Letters::GetQueuedMessages();
is( $messages->[0]->{status}, 'pending',
    'Message is still pending after SendQueuedMessages() because of network failure (bug 14791)' );
is( $messages->[0]->{delivery_note}, 'Connection failed. Attempting to resend.',
    'Message has correct delivery note about resending' );

#DequeueLetter
is(C4::Letters::DequeueLetter( { message_id => $messages->[0]->{message_id} } ), 1, "message successfully dequeued");
$messages = C4::Letters::GetQueuedMessages();
is( @$messages, 0, 'no messages left after dequeue' );

$dbh->rollback;
