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

use Modern::Perl;
use Test::More;
use Test::BDD::Cucumber::StepFile;

use Koha::Database;

use SImpls::MessageQueues;

Given qr/a bunch of message_queue-rows using letter code '(.*?)' and message_transport_type '(.*?)' based on the given Borrowers, Biblios, Items and Issues/, sub {
    my $C = shift;
    my $letterCode = $1;
    my $messageTransportType = $2;
    SImpls::MessageQueues::addMessageQueues($C, $letterCode, $messageTransportType);
};

#Eg set all message_queue-rows to 'status' = 'sent'
Given qr/all message_queue-rows have '(.+?)' as '(.+?)'/, sub {
    my $schema = Koha::Database->new()->schema();
    my $rs = $schema->resultset('MessageQueue')->search({});
    $rs->update( {$1 => $2} );
};

Then qr/I have the following enqueued message queue items/, sub {
    SImpls::MessageQueues::verifyMessageQueueItems( @_ );
};

Then qr/I have the following message queue notices/, sub {
    SImpls::MessageQueues::verifyMessageQueues( @_ );
};
