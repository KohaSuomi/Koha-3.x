package SImpls::Overdues::OverdueCalendar;

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

use Koha::Overdues::Calendar;

sub addOverdueCalendarWeekdays {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    my $ocm = Koha::Overdues::Calendar->new();
    $S->{overdueCalendar} = {} unless $S->{overdueCalendar};
    $F->{overdueCalendar} = {} unless $F->{overdueCalendar};
    for (my $i=0 ; $i<scalar(@{$C->data()}) ; $i++) {
        my $hash = $C->data()->[$i];

        my ($weekdays, $error) = $ocm->upsertWeekdays($hash->{branchCode}, $hash->{weekDays});
        is($error, undef, "Adding OverdueCalendar weekdays succeeded.");

        my $key = $hash->{branchCode};
        $S->{overdueRules}->{$key} = $hash;
        $F->{overdueRules}->{$key} = $hash;
    }
}


sub upsertOverdueCalendarWeekdays {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $matches = $C->matches();
    my $branchCode = $matches->[1];
    my $weekdays = $matches->[0];

    my $calendar = Koha::Overdues::Calendar->new();
    my ($newWeekdays, $error) = $calendar->upsertWeekdays($branchCode, $weekdays);
    $S->{errorCode} = ($error) ? ($error) : '';
}

sub checkOverdueCalendarWeekdays {
    my $C = shift;
    my $matches = $C->matches();
    my $branchCode = $matches->[1];
    my $weekdays = $matches->[0];

    my $calendar = Koha::Overdues::Calendar->new();
    my ($oldWeekdays, $error) = $calendar->getWeekdays($branchCode);
    is($oldWeekdays || $error, $weekdays, "Expected weekdays received")
}

sub deleteOverdueCalendarWeekdays {
    my $C = shift;
    my $matches = $C->matches();
    my $branchCode = $matches->[0];

    my $calendar = Koha::Overdues::Calendar->new();
    $calendar->deleteWeekdays($branchCode);
}

sub upsertOverdueCalendarException {
    my $C = shift;

    my $S = $C->{stash}->{scenario};
    my $matches = $C->matches();
    my $exception = $matches->[0];
    my $branchCode = $matches->[1];

    #Test the DateTime-parameter as well.
    if ($C->stash()->{step}->{inputDateFormat} && $C->stash()->{step}->{inputDateFormat} eq 'DateTime') {
        $exception = Koha::DateUtils::dt_from_string($exception, 'iso');
    }

    my $calendar = Koha::Overdues::Calendar->new();
    my ($newException, $error) = $calendar->upsertException($branchCode, $exception);
    $S->{errorCode} = ($error) ? ($error) : '';
}

sub checkOverdueCalendarException {
    my $C = shift;
    my $matches = $C->matches();
    my $branchCode = $matches->[1];
    my $exception = $matches->[0];

    my $calendar = Koha::Overdues::Calendar->new();
    my ($oldException, $error) = $calendar->getException($branchCode, $exception);
    my $oldYmd = ($oldException) ? $oldException->ymd() : undef;
    is($oldYmd || $error, $exception, "Expected weekdays received")
}

sub deleteOverdueCalendarException {
    my $C = shift;
    my $matches = $C->matches();
    my $exception = $matches->[0];
    my $branchCode = $matches->[1];

    my $calendar = Koha::Overdues::Calendar->new();
    $calendar->deleteException($branchCode, $exception);
}

sub getBranchesAvailableForGathering {
    my $C = shift;
    my $matches = $C->matches();
    my $today = $matches->[0];
    $today = undef if ($today eq 'today');

    my $calendar = Koha::Overdues::Calendar->new();
    my $branches = $calendar->getNotifiableBranches($today);
    $C->{stash}->{scenario}->{availableBranchesForGatheringOverdueNotifications} = $branches;
}

sub checkBranchesAvailableForGathering {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $expectedBranchesString = $C->matches()->[0];
    $expectedBranchesString =~ s/\s+//gsm;
    my $branches = $S->{availableBranchesForGatheringOverdueNotifications};
    my $gotBranchesString = (ref $branches eq 'ARRAY') ? join(',', @$branches) : '';
    is($gotBranchesString, $expectedBranchesString, "Branches available for overdue notice gathering");
}

sub deleteAllOverdueCalendarRules {
    my $calendar = Koha::Overdues::Calendar->new();
    $calendar->deleteAllWeekdays();
    $calendar->deleteAllExceptiondays();
}

1;
