package SImpls::SystemPreferences;

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
use Test::More;

use C4::Context;

sub setSystemPreferences {
    my $C = shift;

    my $data = $C->data();
    foreach my $syspref (@$data) {
        setSystemPreference($C, $syspref->{systemPreference}, $syspref->{value});
    }
}
sub setSystemPreference {
    my ($C, $key, $value) = @_;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    $S->{originalSystempreferences} = {} unless $S->{originalSystempreferences};
    $F->{originalSystempreferences} = {} unless $F->{originalSystempreferences};

    if ($S->{originalSystempreferences}->{$key} && $F->{originalSystempreferences}->{$key}) {
        #This syspref has been set from somewhere already, so let's not remove the stored original value.
    }
    else {
        my $oldSysprefValue = C4::Context->preference($key);
        $S->{originalSystempreferences}->{$key} = $oldSysprefValue;
        $F->{originalSystempreferences}->{$key} = $oldSysprefValue;
    }
    C4::Context->set_preference($key, $value);
}

sub rollbackSystemPreferences {
    my $C = shift;
    my $F = $C->{stash}->{feature};
    if (ref $F->{originalSystempreferences} eq 'HASH') {
        while (my ($syspref, $value) = each(%{$F->{originalSystempreferences}})) {
            C4::Context->set_preference($syspref, $value);
        }
    }
}

1;
