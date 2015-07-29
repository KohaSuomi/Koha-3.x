package Koha::Serial::Subscription;

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
use Koha::Serial::Subscription::Frequencies;
use Koha::Serial::Subscription::Numberpatterns;
use Koha::Serial::Serials;
use Koha::Borrowers;
use Koha::Biblios;
use Koha::Acquisition::Booksellers;
use Koha::Items;

use base qw(Koha::Object);

sub type {
    return 'Subscription';
}

sub periodicity {
    my ($self, $periodicity) = @_;

    if ($periodicity) {
        $periodicity = Koha::Serial::Subscription::Frequencies->cast($periodicity);
        $self->{periodicity} = $periodicity;
        $self->set({periodicity => $periodicity->_result()->id});
        $self->store();
    }

    unless ($self->{periodicity}) {
        my $frequency = $self->_result()->periodicity();
        $self->{periodicity} = Koha::Serial::Subscription::Frequencies->cast($frequency);
    }

    return $self->{periodicity};
}

sub numberpattern {
    my ($self, $numberpattern) = @_;

    if ($numberpattern) {
        $numberpattern = Koha::Serial::Subscription::Numberpatterns->cast($numberpattern);
        $self->{numberpattern} = $numberpattern;
        $self->set({numberpattern => $numberpattern->_result()->id});
        $self->store();
    }

    unless ($self->{numberpattern}) {
        my $numberpattern = $self->_result()->numberpattern();
        $self->{numberpattern} = Koha::Serial::Subscription::Numberpatterns->cast($numberpattern);
    }

    return $self->{numberpattern};
}

sub biblio {
    my ($self, $biblio) = @_;

    if ($biblio) {
        $biblio = Koha::Biblios->cast($biblio);
        $self->{biblio} = $biblio;
        $self->set({biblio => $biblio->_result()->id});
        $self->store();
    }

    unless ($self->{biblio}) {
        my $biblio = $self->_result()->biblio();
        $self->{biblio} = Koha::Biblios->cast($biblio);
    }

    return $self->{biblio};
}

sub borrower {
    my ($self, $borrower) = @_;

    if ($borrower) {
        $borrower = Koha::Borrowers->cast($borrower);
        $self->{borrower} = $borrower;
        $self->set({librarian => $borrower->_result()->id});
        $self->store();
    }

    unless ($self->{borrower}) {
        my $borrower = $self->_result()->librarian();
        $self->{borrower} = Koha::Borrowers->cast($borrower);
    }

    return $self->{borrower};
}

sub bookseller {
    my ($self, $bookseller) = @_;

    if ($bookseller) {
        $bookseller = Koha::Acquisition::Booksellers->cast($bookseller);
        $self->{bookseller} = $bookseller;
        $self->set({bookseller => $bookseller->_result()->id});
        $self->store();
    }

    unless ($self->{bookseller}) {
        my $booksellerid = $self->_result()->aqbooksellerid();
        $self->{bookseller} = Koha::Acquisition::Booksellers->cast($booksellerid);
    }

    return $self->{bookseller};
}

sub serials {
    my ($self) = @_;

    unless ($self->{serials}) {
        my @serials = Koha::Serial::Serials->search({subscriptionid => $self->subscriptionid});
        $self->{serials} = \@serials;
    }

    return $self->{serials};
}

sub items {
    my ($self) = @_;

    unless ($self->{items}) {
        my @items;
        my $serials = $self->serials();
        for (my $i=0 ; $i<scalar(@$serials) ; $i++) {
            my @serialitems = $serials->[$i]->_result()->serialitems();
            foreach my $si (@serialitems) {
                my $item = $si->itemnumber;
                $item = Koha::Items->cast($item);
                push @items, $item;
            }
        }
        $self->{items} = \@items;
    }

    return $self->{items};
}

1;
