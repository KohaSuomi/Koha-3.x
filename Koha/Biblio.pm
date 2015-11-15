package Koha::Biblio;

# Copyright Open Source Freedom Fighters
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
use Koha::Serial::Subscriptions;

use base qw(Koha::Object);

sub type {
    return 'Biblio';
}

sub subscription {
    my ($self) = @_;
    return $self->{subscription} if $self->{subscription};

    my $resultset = Koha::Database->new->schema->resultset('Subscription');
    $self->{subscription} = $resultset->search({biblionumber => $self->biblionumber}, {limit => 1})->next();
    $self->{subscription} = Koha::Serial::Subscriptions->cast($self->{subscription});
    return $self->{subscription};
}

sub subscriptions {
    my ($self) = @_;
    return $self->{subscriptions} if $self->{subscriptions};

    my $resultset = Koha::Database->new->schema->resultset('Subscription');
    my @subscriptions = Koha::Serial::Subscriptions->search({biblionumber => $self->biblionumber});
    $self->{subscriptions} = \@subscriptions;
    return $self->{subscriptions};
}

1;
