package C4::SelfService;

# Copyright 2016 KohaSuomi
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

use DateTime::Format::ISO8601;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Carp;

use C4::Context;
use C4::Log;
use C4::Members::Attributes;

use Koha::Exception::SelfService;
use Koha::Exception::SelfService::Underage;
use Koha::Exception::SelfService::TACNotAccepted;

=head2 CheckSelfServicePermission

=cut

sub CheckSelfServicePermission {
    my ($ilsPatron, $requestingBranchcode, $action) = @_;
    $requestingBranchcode = '' unless $requestingBranchcode;
    $action = 'accessMainDoor' unless $action;

    try {
        _HasSelfServicePermission($ilsPatron, $requestingBranchcode, $action);
    } catch {
        unless (blessed($_) && $_->can('rethrow')) {
            confess $_;
        }
        if (blessed($_) && $_->isa('Koha::Exception::SelfService::Underage')) {
            _WriteAccessLog($action, $ilsPatron->{borrowernumber}, 'underage');
            $_->rethrow();
        }
        elsif (blessed($_) && $_->isa('Koha::Exception::SelfService::TACNotAccepted')) {
            _WriteAccessLog($action, $ilsPatron->{borrowernumber}, 'missingT&C');
            $_->rethrow();
        }
        elsif (blessed($_) && $_->isa('Koha::Exception::SelfService')) {
            _WriteAccessLog($action, $ilsPatron->{borrowernumber}, 'denied');
            $_->rethrow();
        }
        $_->rethrow;
    };

    _WriteAccessLog($action, $ilsPatron->{borrowernumber}, 'granted');
    return 1;
}

sub _HasSelfServicePermission {
    my ($ilsPatron, $requestingBranchcode, $action) = @_;

    _CheckLimitation($ilsPatron);
    _CheckMinimumAge($ilsPatron);
    _CheckTaC($ilsPatron);

    return 1;
}

sub _CheckLimitation {
    my ($ilsPatron) = @_;

    if (
        $ilsPatron->card_lost ||
        $ilsPatron->expired ||
        not($ilsPatron->hold_ok) || #debarred
        $ilsPatron->excessive_fines ||
        $ilsPatron->excessive_fees) {

        Koha::Exception::SelfService->throw();
    }
}

sub _CheckMinimumAge {
    my ($ilsPatron) = @_;
    my $minimumAge = 15;
    my $dob = DateTime::Format::ISO8601->parse_datetime($ilsPatron->{birthdate_iso});
    $dob->set_time_zone( C4::Context->tz() );
    my $minimumDob = DateTime->now(time_zone => C4::Context->tz())->subtract(years => $minimumAge);
    if (DateTime->compare($dob, $minimumDob) > 0) {
        Koha::Exception::SelfService::Underage->throw(minimumAge => $minimumAge);
    }
    return 1;
}

sub _CheckTaC {
    my ($ilsPatron) = @_;
    my $agreement = C4::Members::Attributes::GetBorrowerAttributeValue($ilsPatron->{borrowernumber}, 'SST&C');
    unless ($agreement) {
        Koha::Exception::SelfService::TACNotAccepted->throw();
    }
    return 1;
}

sub GetAccessLogs {
    my ($userNumber) = @_;

    return C4::Log::GetLogs(undef, undef, undef, ['SS'], undef, $userNumber, undef);
}

=head2 _WriteAccessLog

@PARAM1 String, action to log, typically 'accessMainDoor' or other Self-service component
@PARAM2 Int, the borrowernumber of the user accessing the Self-service resource
@PARAM3 String, what was the outcome of the authorization? Typically 'denied', 'granted', 'underage', 'missingT&C'
@RETURNS undef, since C4::Log has no useful return values.

=cut

sub _WriteAccessLog {
    my ($action, $accessingBorrowernumber, $resolution) = @_;
    C4::Log::logaction('SS', $action, $accessingBorrowernumber, $resolution);
}

=head2

Deletes all Self-service logs from the koha.action_logs-table

=cut

sub FlushLogs {
    C4::Context->dbh->do("DELETE FROM action_logs WHERE module = 'SS'");
}

1;
