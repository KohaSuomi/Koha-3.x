package SImpls::Context;

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
use Carp;

use C4::Context;

sub setKohaContext {
    my $C = shift;

    my $contextHash = $C->{_data}->[0];
    C4::Context->_new_userenv($contextHash->{userenvName} || 'DUMMY SESSION');
    C4::Context->set_userenv(
            0,
            0,
            0,
            $contextHash->{firstName}      || 'firstname',
            $contextHash->{surname}        || 'surname',
            $contextHash->{branchCode}     || 'CPL',
            $contextHash->{branchName}     || 'Centerville Public Library',
            $contextHash->{userFlags}      || 0,
            $contextHash->{userEmail}      || 'noemail@example.com',
            $contextHash->{branchPrinter}  || 'branchPrinter?',
    );
}

1;
