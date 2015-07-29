package Koha::Serial::Subscription::Frequency;

# Copyright KohaSuomi 2015
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

use Koha::Database;

use base qw(Koha::Object);

sub type {
    return 'SubscriptionFrequency';
}

sub subscriptions {
    my ($self) = @_;

    unless ($self->{subscriptions}) {
        my @subscriptions = Koha::Serial::Subscriptions->search({periodicity => $self->id});
        $self->{subscriptions} = \@subscriptions;
    }

    return $self->{subscriptions};
}

1;
