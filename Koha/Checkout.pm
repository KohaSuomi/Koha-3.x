package Koha::Checkout;

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
use Koha::Borrowers;
use Koha::Items;

use base qw(Koha::Object);

sub type {
    return 'Issue';
}

sub cardnumber {
    my ($self) = @_;

    unless ($self->{borrower}) {
        $self->{borrower} = Koha::Borrowers->cast($self->_result->borrower);
    }
    return $self->{borrower}->cardnumber;
}

sub barcode {
    my ($self) = @_;

    unless ($self->{item}) {
        $self->{item} = Koha::Items->cast($self->_result->item);
    }
    return $self->{item}->barcode;
}

1;
