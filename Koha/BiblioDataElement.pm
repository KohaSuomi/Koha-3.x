package Koha::BiblioDataElement;

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

use Koha::Database;

use base qw(Koha::Object);

sub type {
    return 'BiblioDataElement';
}

sub isFiction {
    my ($self, $record) = @_;

    my $sf = $record->subfield('084','a');
    if ($sf && $sf =~/^8[1-5].*/) { #ykl numbers 81.* to 85.* are fiction.
        $self->set({fiction => 1});
    }
    else {
        $self->set({fiction => 0});
    }
}

sub isMusicalRecording {
    my ($self, $record) = @_;

    my $sf = $record->subfield('084','a');
    if ($sf && $sf =~/^78.*/) { #ykl number 78 is a musical recording.
        $self->set({musical => 1});
    }
    else {
        $self->set({musical => 0});
    }
}

sub isSerial {
    my ($self, $itemtype) = @_;
    my $serial = ($itemtype && ($itemtype eq 'AL' || $itemtype eq 'SL')) ? 1 : 0;
    if ($serial) {
        $self->set({serial => 1});
    }
    else {
        $self->set({serial => 0});
    }
}

sub setItemtype {
    my ($self, $itemtype) = @_;

    $self->set({itemtype => $itemtype});
}

=head setLanguages

    $bde->setLanguage($record);

Sets the languages- and primary_language-columns.
Primary language defaults to FIN if 041$a is not defined.
Warns if multiple primary languages are found.
@PARAM1, MARC::Record

=cut

sub setLanguages {
    my ($self, $record) = @_;

    my $primaryLanguage; #Did we find the primary language?
    my @sb; #StrinBuilder to efficiently collect language Strings and concatenate them
    my $f041 = $record->field('041');

    if ($f041) {
        my @sfs = $f041->subfields();
        @sfs = sort {$a->[0] cmp $b->[0]} @sfs;

        foreach my $sf (@sfs) {
            unless (ref $sf eq 'ARRAY' && $sf->[0] && $sf->[1]) { #Code to fail :)
                print "Biblioitemnumber '".$self->biblioitemnumber()."' has a bad language subfield\n";
                next;
            }
            push @sb, $sf->[0].':'.$sf->[1];
            if ($sf->[0] eq 'a') { #We got the primary language subfield
                if ($primaryLanguage) {
                    print "Biblioitemnumber '".$self->biblioitemnumber()."' has a duplicate primary language subfield 'a'\n";
                }
                else {
                    $primaryLanguage = $sf->[1];
                    $self->set({primary_language => $primaryLanguage});
                }
            }
        }
    }

    $self->set({languages => join(',',@sb)}) if scalar(@sb);
    $self->set({primary_language => 'FIN'}) unless $primaryLanguage; #Defaults to FIN for obvious reasons :)
}

sub setDeleted {
    my ($self, $deleted) = @_;

    $self->set({deleted => 1}) if $deleted;
    $self->set({deleted => undef}) unless $deleted;
}

1;
