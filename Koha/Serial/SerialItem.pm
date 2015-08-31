package Koha::Serial::SerialItem;

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
use Koha::Items;
use Koha::Serial::Serials;

use Koha::Exception::BadParameter;

=head SerialItem

=head SYNOPSIS

This class deals with displaying Serials, whether or not they have Items or not.

=cut

sub new {
    my ($class, $serial, $item) = @_;

    my $self = {};
    bless($self, $class);

    Koha::Exception::BadParameter->throw(error => __PACKAGE__."->new():> You must give a Serial-object as a parameter!")
                    unless $serial;
    $self->{serial} = Koha::Serial::Serials->cast($serial) if $serial;
    $item = $serial->_result->serialitems->itemnumber unless $item;
    $self->{item}   = Koha::Items->cast($item) if $item;

    return $self;
}

#sub getItem {
#    my ($self) = @_;
#    return $self->{item};
#}

#sub getSerial {
#    my ($self) = @_;
#    return $self->{serial};
#}

1;
