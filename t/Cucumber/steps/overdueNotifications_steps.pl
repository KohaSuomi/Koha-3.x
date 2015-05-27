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

use C4::Context;

use Koha::Overdues::Controller;
use SImpls::Overdues::OverdueNotifications;


Given qr/there are no previous overdue notifications/, sub {
    SImpls::Overdues::OverdueNotifications::deleteAllOverdueNotifications(@_);
};

When qr/I gather overdue notifications, with following parameters/, sub {
    SImpls::Overdues::OverdueNotifications::gather_overdue_notifications_with_parameters( @_ );
};

When qr/I gather overdue notifications, (separating|merging) results from all branches/, sub {
    my $controller = Koha::Overdues::Controller->new();
    my $mergeOrSeparate = ($1 eq 'merging') ? 1 : undef;
    $controller->gatherOverdueNotifications(undef, undef, $mergeOrSeparate);
};

When qr/I send overdue notifications/, sub {
    SImpls::Overdues::OverdueNotifications::send_overdue_notifications( @_ );
};

When qr/I fast-forward '(\d+)' '(days)'/, sub {
    SImpls::Overdues::OverdueNotifications::fast_forward_in_time( shift, $1, $2 );
};
