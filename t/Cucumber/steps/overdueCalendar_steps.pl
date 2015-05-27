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

use SImpls::Items;
use SImpls::Overdues::OverdueCalendar;
use Koha::Overdues::Calendar;

Given qr/the following overdue notification weekdays/, sub {
    SImpls::Overdues::OverdueCalendar::addOverdueCalendarWeekdays(@_);
};

Given qr/there are no Overdues Calendar notification gathering weekdays/, sub {
    my $calendar = Koha::Overdues::Calendar->new();
    $calendar->deleteAllWeekdays();
};

Given qr/there are no Overdues Calendar notification gathering exception days/, sub {
    my $calendar = Koha::Overdues::Calendar->new();
    $calendar->deleteAllExceptiondays();
};

When qr/I've added Overdue notification weekdays '(.*?)' for branch '(.*?)'/, sub {
    SImpls::Overdues::OverdueCalendar::upsertOverdueCalendarWeekdays( @_ );
};

When qr/I've updated Overdue notification weekdays '(.*?)' for branch '(.*?)'/, sub {
    SImpls::Overdues::OverdueCalendar::upsertOverdueCalendarWeekdays( @_ );
};

When qr/I've deleted Overdue notification weekdays from branch '(.*?)'/, sub {
    SImpls::Overdues::OverdueCalendar::deleteOverdueCalendarWeekdays( @_ );
};

When qr/I get branches available for gathering, pretending that today is '(\d\d\d\d-\d\d-\d\d|today)'/, sub {
    SImpls::Overdues::OverdueCalendar::getBranchesAvailableForGathering( @_ );
};

When qr/I display the Overdues Calendar for the next '(\d+)' '(weeks|days)' as text for branch '(.*?)', pretending that today is '(\d\d\d\d-\d\d-\d\d)'/, sub {
    my $calendar = Koha::Overdues::Calendar->new();
    my ($text, $error) = $calendar->toString($3, $4, undef, $1, $2); #branchCode, startDate, endingDate, duration, durationUnit
    S->{scenario}->{overdueCalendarAsText} = $text;
};

When qr/I've added Overdue notification exception day '(.*?)' for branch '(.*?)'/, sub {
    SImpls::Overdues::OverdueCalendar::upsertOverdueCalendarException( @_ );
};

When qr/I've added Overdue notification exception day '(.*?)' as DateTime for branch '(.*?)'/, sub {
    my $C = shift;
    $C->stash()->{step}->{inputDateFormat} = 'DateTime';
    SImpls::Overdues::OverdueCalendar::upsertOverdueCalendarException( $C );
};

When qr/I've updated Overdue notification exception day '(.*?)' for branch '(.*?)'/, sub {
    SImpls::Overdues::OverdueCalendar::upsertOverdueCalendarException( @_ );
};

When qr/I've deleted Overdue notification exception day '(\d\d\d\d-\d\d-\d\d)' for branch '(.*?)'/, sub {
    SImpls::Overdues::OverdueCalendar::deleteOverdueCalendarException( @_ );
};

Then qr/getting Overdue notification weekdays '(.*?)' for branch '(.*?)'/, sub {
    SImpls::Overdues::OverdueCalendar::checkOverdueCalendarWeekdays( @_ );
};

Then qr/these branches '(.*?)' are available for overdue notice gathering/, sub {
    SImpls::Overdues::OverdueCalendar::checkBranchesAvailableForGathering( @_ );
};

Then qr/I get the following output/, sub {
    my $C = shift;
    my $hereDoc = $C->data(); #There is an awkward end-of-line when the hereDoc is not empty, and no end-of-line when it is empty.
    $hereDoc =~ s/\s+$//;
    my $text = S->{scenario}->{overdueCalendarAsText};
    $hereDoc =~ s/\s+$//;
    is($text, $hereDoc, "Text matches");
};

Then qr/I get this error '(.*?)'/, sub {
    my $C = shift;
    my $errorCode = S->{errorCode};
    is($errorCode, $C->matches()->[0], "Error matches");
};

Then qr/getting Overdue notification exception day '(.*?)' for branch '(.*?)'/, sub {
    SImpls::Overdues::OverdueCalendar::checkOverdueCalendarException( @_ );
};
