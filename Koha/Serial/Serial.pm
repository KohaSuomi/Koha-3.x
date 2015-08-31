package Koha::Serial::Serial;

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
    return 'Serial';
}

sub item {
    my ($self, $item) = @_;

    if ($item) {
        $item = Koha::Items->cast($item);
        $self->{item} = $item;
        $self->set({item => $item->_result()->id});
        $self->store();
    }

    unless ($self->{item}) {
        my $item = $self->_result()->serialitems()->itemnumber(); #itemnumber actually returns the Item-resultset :)
        $self->{item} = Koha::Items->cast($item);
    }

    return $self->{item};
}

sub subscription {
    my ($self, $subscription) = @_;

    if ($subscription) {
        $subscription = Koha::Serial::Subscriptions->cast($subscription);
        $self->{subscription} = $subscription;
        $self->set({subscription => $subscription->_result()->id});
        $self->store();
    }

    unless ($self->{subscription}) {
        my $subscription = $self->_result()->subscription();
        $self->{subscription} = Koha::Serial::Subscriptions->cast($subscription);
    }

    return $self->{subscription};
}

1;
