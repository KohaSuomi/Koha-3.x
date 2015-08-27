package t::lib::TestObjects::MessageQueueFactory;

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
use Carp;
use Scalar::Util qw(blessed);

use C4::Members;
use C4::Letters;
use Koha::Borrowers;

use base qw(t::lib::TestObjects::ObjectFactory);

use Koha::Exception::ObjectExists;

sub new {
    my ($class) = @_;

    my $self = {};
    bless($self, $class);
    return $self;
}

sub getDefaultHashKey {
    return 'from_address';
}
sub getObjectType {
    return 'HASH';
}

=head createTestGroup( $data [, $hashKey, $testContexts...] )
@OVERLOADED

    MessageQueueFactory creates a new message into message_queue table with 'pending'
    status. After testing, all messages created by the MessageQueueFactory will be
    deleted at tearDown.

    my $messages = t::lib::TestObjects::MessageQueueFactory->createTestGroup([
                         subject => "Test title",
                         content => "Tessst content",
                         cardnumber => $borrowers->{'superuberadmin'}->cardnumber,
                         message_transport_type => 'sms',
                         from_address => 'test@unique.com',
                         },
                    ], undef, $testContext1, $testContext2, $testContext3);

    #Do test stuff...

    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext1);
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext2);
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext3);

See t::lib::TestObjects::ObjectFactory for more documentation
=cut

sub handleTestObject {
    my ($class, $notice, $stashes) = @_;

    my $borrower = Koha::Borrowers->cast($notice->{cardnumber});

    my $letter = {
        title => $notice->{subject} || '',
        content => $notice->{content},
        content_type => $notice->{content_type},
        letter_code => $notice->{letter_code},
    };
    my $message_id = C4::Letters::EnqueueLetter({
        letter                 => $letter,
        borrowernumber         => $borrower->borrowernumber,
        message_transport_type => $notice->{message_transport_type},
        to_address             => $notice->{to_address},
        from_address           => $notice->{from_address},
    });

    $notice->{message_id} = $message_id;

    return $notice;
}

=head validateAndPopulateDefaultValues
@OVERLOAD

Validates given Object parameters and makes sure that critical fields are given
and populates defaults for missing values.
=cut

sub validateAndPopulateDefaultValues {
    my ($class, $object, $hashKey) = @_;
    $class->SUPER::validateAndPopulateDefaultValues($object, $hashKey);

    unless ($object->{cardnumber}) {
        Koha::Exception::BadParameter->throw(error => __PACKAGE__."->createTestGroup():> 'cardnumber' is a mandatory parameter!");
    }
    unless ($object->{from_address}) {
        Koha::Exception::BadParameter->throw(error => __PACKAGE__."->createTestGroup():> 'from_address' is a mandatory parameter!");
    }

    # Other required fields
    $object->{message_transport_type} = 'email' unless defined $object->{message_transport_type};
    $object->{content} => "Example message content" unless defined $object->{content};
}

=head deleteTestGroup
@OVERLOADED

    my $records = createTestGroup();
    ##Do funky stuff
    deleteTestGroup($prefs);

Removes the given test group from the DB.

=cut

sub deleteTestGroup {
    my ($class, $messages) = @_;

    my $schema = Koha::Database->new_schema();
    while( my ($key, $msg) = each %$messages) {
        if ($schema->resultset('MessageQueue')->find({"message_id" => $msg->{message_id}})) {
            $schema->resultset('MessageQueue')->find({"message_id" => $msg->{message_id}})->delete();
        }
    }
}

sub _deleteTestGroupFromIdentifiers {
    my ($self, $testGroupIdentifiers) = @_;

    my $schema = Koha::Database->new_schema();
    foreach my $key (@$testGroupIdentifiers) {
        if ($schema->resultset('MessageQueue')->find({"from_address" => $key})) {
            $schema->resultset('MessageQueue')->find({"from_address" => $key})->delete();
        }
    }
}


1;
