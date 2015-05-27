package SImpls::Overdues::OverdueNotifications;

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
use Carp;

use Test::More;
use Koha::Database;
use Koha::DateUtils;

use SImpls::SystemPreferences;

=head fast_forward_in_time
Because it is impossible to cheat the mktime() and localtime() C-functions,
the second best is to move the dueDate and dateIssue in the Issues table :)
Also the message_queue.time_queued needs to be moved to.
=cut

sub deleteAllOverdueNotifications {
    require Koha::MessageQueue::Notification::Overdues;
    my $C = shift;
    my @overdueNotifications = Koha::MessageQueue::Notification::Overdues->search({});
    $_->delete() for @overdueNotifications;
}

sub fast_forward_in_time {
    my ($C, $time, $timeUnit) = @_;
    my $S = $C->{stash}->{scenario};
    $timeUnit = 'days' unless $timeUnit;

    my $schema = Koha::Database->new()->schema();
    my @issues = $schema->resultset('Issue')->search({});
    #We actually should use the %{$S->{issues}} -HASH, but since it contains the old issues as HASHes from
    #C4::Circulation::GetIssues() and the C4::Issues has no way of modifying an existing Issue, we revert to DBIx.
    foreach my $issue (@issues) {
        my $dueDate = Koha::DateUtils::dt_from_string( $issue->date_due, 'iso');
        $dueDate->subtract($timeUnit => $time);
        my $issueDate = Koha::DateUtils::dt_from_string( $issue->issuedate, 'iso');
        $issueDate->subtract($timeUnit => $time);
        $issue->update({ date_due => $dueDate->iso8601(),
                         issuedate => $issueDate->iso8601(),
                      });
    }
    my @messageQueues = $schema->resultset('MessageQueue')->search({});
    foreach my $messageQueue (@messageQueues) {
        my $timeQueued = Koha::DateUtils::dt_from_string( $messageQueue->time_queued(), 'iso');
        $timeQueued->subtract($timeUnit => $time);
        $messageQueue->update({time_queued => $timeQueued});
    }
}

sub gather_overdue_notifications_with_parameters {
    my $C = shift;

    my $data = $C->data();
    my $params = $data->[0] if $data && ref $data eq 'ARRAY';

    if ($params->{_repeatPageChange}) {
        my $repeatPageChange = {};
        if ($params->{_repeatPageChange} =~ /items.*?"(\d+)"/) {
            $repeatPageChange->{items} = $1;
        }
        if ($params->{_repeatPageChange} =~ /separator.*?"(.*?)"/) {
            $repeatPageChange->{separator} = $1;
            $repeatPageChange->{separator} =~ s/\\n/\n/gis;
        }
        $params->{_repeatPageChange} = $repeatPageChange;
    }
    
    my $controller = Koha::Overdues::Controller->new($params);
    $controller->gatherOverdueNotifications(undef, undef);
}

sub send_overdue_notifications {
    my $C = shift;

    #Make sure that we have some kind of PrintProviderImplementation selected
    unless (C4::Context->preference('PrintProviderImplementation')) {
        SImpls::SystemPreferences::setSystemPreference($C, 'PrintProviderImplementation', 'PrintProviderLimbo');
    }

    my $controller = Koha::Overdues::Controller->new();
    $controller->sendOverdueNotifications();
}

1;
