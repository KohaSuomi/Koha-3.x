package SImpls::MessageQueues;

# Copyright 2015 Vaara-kirjastot
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
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
use Carp;
use Test::More;

use Koha::Database;
use C4::Context;

sub addMessageQueues {
    my $C = shift;
    my $letterCode = shift;
    my $messageTransportType = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    $S->{message_queues} = {} unless $S->{message_queues};
    $F->{message_queues} = {} unless $F->{message_queues};
    foreach my $cardumber (sort keys %{$S->{borrowers}}) {
        my $borrower = $S->{borrowers}->{$cardumber};

        my @repeat;
        foreach my $i ( sort keys %{$S->{issues}} ) {
            my $issue = $S->{issues}->{$i};
            if ( $issue->{borrowernumber} eq $borrower->{borrowernumber} ) {
                my $itemForCurrentBorrower = $S->{items}->{  $issue->{itemnumber}  };
                push @repeat, {items => $itemForCurrentBorrower};
            }
        }
        my $letter = C4::Letters::GetPreparedLetter (
                        module => 'circulation',
                        letter_code => $letterCode,
                        branchcode => $borrower->{branchcode},
                        tables => {borrowers => $borrower},
                        #substitute => $substitute,
                        repeat => { item => \@repeat },
                        message_transport_type => $messageTransportType,
        );
        my $mqHash = {
                        letter                 => $letter,
                        borrowernumber         => $borrower->{borrowernumber},
                        message_transport_type => $messageTransportType,
                        from_address           => C4::Context->preference('KohaAdminEmailAddress'),
                        to_address             => 'dontsend@example.com',
        };
        my $message_queue_id = C4::Letters::EnqueueLetter( $mqHash );
        like($message_queue_id, qr/^\d+$/, "Message enqueued.");
        $S->{message_queues}->{$message_queue_id} = $mqHash;
        $F->{message_queues}->{$message_queue_id} = $mqHash;
    }
}

sub deleteAllMessageQueues {
    my $C = shift;
    my $F = $C->{stash}->{feature};
    my $schema = Koha::Database->new()->schema();

    $schema->resultset('MessageQueue')->search({})->delete_all();
}

sub verifyMessageQueueItems {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};
    my $checks = $C->data(); #Get the checks, which might not have manifested itselves to the message_queue_items
    ok(($checks && scalar(@$checks) > 0), "You must give checks as the data");

    #See which checks are supposed to be in the message_queue_item-table, and which are just to clarify intent.
    my @checksInTable;
    foreach my $check (@$checks) {
        my $status = $check->{status};
        push @checksInTable, $check if ($status ne 'not_odue' && $status ne 'no_rule');
    }

    ##Make sure that there are no trailing MessageQueueItems.
    my $schema = Koha::Database->new()->schema();
    my $allMessageQueueItemsCount = $schema->resultset('MessageQueueItem')->search({})->count();
    is($allMessageQueueItemsCount, scalar(@checksInTable), "We should have ".scalar(@checksInTable)." checks for $allMessageQueueItemsCount message_queue_items, with no trailing items.");

    #Expressing the following cannot be comfortably done with DBIx
    #especially since message_queue_items-table should not have foreign key linkings to items and issues-tables.
    my $dbh = C4::Context->dbh();
    my $check_statement = $dbh->prepare(
        "SELECT 1 FROM message_queue_items mi ".
        "LEFT JOIN message_queue mq ON mi.message_id = mq.message_id ".
        "LEFT JOIN borrowers b ON mq.borrowernumber = b.borrowernumber ".
        "LEFT JOIN items i ON mi.itemnumber = i.itemnumber ".
        "LEFT JOIN issues iss ON iss.issue_id = mi.issue_id ".
        "WHERE b.cardnumber = ? AND i.barcode = ? AND mi.branch = ? AND mq.letter_code = ? ".
        "AND mi.letternumber = ? AND mq.status = ?  AND mq.message_transport_type = ? ".
    "");

    ##Check that there is a matching MessageQueueItem for each given test.
    foreach my $check (@checksInTable) {
        my @params;
        push @params, $check->{cardnumber};
        push @params, $check->{barcode};
        push @params, $check->{branch};
        push @params, $check->{lettercode};
        push @params, $check->{letternumber};
        push @params, $check->{status};
        push @params, $check->{transport_type};
        $check_statement->execute( @params );
        my $ok = $check_statement->fetchrow();
        last unless ok(($ok && $ok == 1), "Check: For params @params");
    }
}

sub verifyMessageQueues {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    my $checks = $C->data(); #Get the checks, which might not have manifested itselves to the message_queues
    ok(($checks && scalar(@$checks) > 0), "You must give checks as the data");

    ##Make sure that there are no trailing MessageQueueItems.
    my $schema = Koha::Database->new()->schema();
    my $allMessageQueuesCount = $schema->resultset('MessageQueue')->search({})->count();
    is($allMessageQueuesCount, scalar(@$checks), "We should have ".scalar(@$checks)." checks for $allMessageQueuesCount message_queue_items, with no trailing items.");

    my @all = $schema->resultset('MessageQueue')->search({});
    foreach my $a ( @all ) {
        print $a->content()."\n";
    }

    if ($checks->[0]->{contentRegexp}) {
        verifyMessageQueuesFromContentRegexp($checks);
    }
    elsif ($checks->[0]->{containedBarcodes}) {
        verifyMessageQueuesFromBarcodes($checks);
    }
    else {
        die "\nverifyMessageQueues():> The MessageQueues-data table must contain column 'barcodes', or 'contentRegexp'.\n".
            "'barcodes' contains comma separated list of barcodes that must be found inside the message_queue.content.\n".
            "'contentRegexp' is a regexp that must match with the message_queue.content.\n";
    }
}

sub verifyMessageQueuesFromBarcodes {
    my ($checks) = @_;

    my $dbh = C4::Context->dbh();
    my $check_statement = $dbh->prepare(
        "SELECT 1 FROM message_queue mq ".
        "LEFT JOIN message_queue_items mqi ON mqi.message_id = mq.message_id ".
        "LEFT JOIN borrowers b ON mq.borrowernumber = b.borrowernumber ".
        "LEFT JOIN items i ON mqi.itemnumber = i.itemnumber ".
        "WHERE b.cardnumber = ? ".
        "AND i.barcode = ? ".
        "AND mq.letter_code = ? ".
        "AND mq.status = ? ".
        "AND mq.message_transport_type = ? ".
    "");

    ##Check that there is a matching MessageQueue for each given test.
    foreach my $check (@$checks) {
        my @barcodes = map {my $a = $_; $a =~ s/\s+//gsm; $a;} split(',',$check->{containedBarcodes});
        foreach my $bc (@barcodes) {
            my @params;
            push @params, $check->{cardnumber};
            push @params, $bc;
            push @params, $check->{lettercode};
            push @params, $check->{status};
            push @params, $check->{transport_type};
            $check_statement->execute( @params );
            my $ok = $check_statement->fetchrow();
            last unless ok(($ok && $ok == 1), "Check: For params @params");
        }
    }
}
sub verifyMessageQueuesFromContentRegexp {
    my ($checks) = @_;

    my $dbh = C4::Context->dbh();
    my $check_statement = $dbh->prepare(
        "SELECT 1 FROM message_queue mq ".
        "LEFT JOIN borrowers b ON mq.borrowernumber = b.borrowernumber ".
        "WHERE b.cardnumber = ? ".
        "AND mq.letter_code = ? ".
        "AND mq.status = ? ".
        "AND mq.message_transport_type = ? ".
        "AND mq.content REGEXP ? ".
    "");

    ##Check that there is a matching MessageQueue for each given test.
    foreach my $check (@$checks) {
        my @params;
        push @params, $check->{cardnumber};
        push @params, $check->{lettercode};
        push @params, $check->{status};
        push @params, $check->{transport_type};
        push @params, $check->{contentRegexp};
        $check_statement->execute( @params );
        my $ok = $check_statement->fetchrow();
        last unless ok(($ok && $ok == 1), "Check: For params @params");
    }
}

1;
