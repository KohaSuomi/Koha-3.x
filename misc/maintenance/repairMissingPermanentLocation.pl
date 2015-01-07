#!/usr/bin/perl

#-----------------------------------
# Copyright 2015 Vaara-kirjastot
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#-----------------------------------

use Modern::Perl;

use C4::Context;
use C4::OPLIB::Labels;
use C4::Items;

use DateTime;
use Data::Dumper;
use Getopt::Long;

my ($help, $confirm, $verbose);

GetOptions(
  'h|help'     => \$help,
  'v|verbose'  => \$verbose,
  'c|confirm'  => \$confirm,
);

my $usage = << 'ENDUSAGE';

Repair missing permanent_location/location from the itemcallnumbers'' location code.
Thanks to Bug 7817 and still persisting?

Repair happens using the following rules:
1. If a location exists and is not 'CART', we can substitute a missing permanent_location, or a 'CART', with it.
2. If a permanent_location exists and is not 'CART', we can substitute a missing location with it, but only if
   the location is empty! (We can have genuine Items "checked-in today")
3. Decompose the shelving label to find the original location for both the location and the permanent_location.


  -h --help    This nice help!

  -v --verbose More chatty output :)

  -c --confirm Confirm that you want to overwrite all CART and NULL permanent_locations/locations
               with something proper from the shelving location mapper.

ENDUSAGE

if ($help || !$confirm) {
    print $usage;
    exit 0;
}

my $reverseLabelMap = C4::OPLIB::Labels::getReverseShelvingLabelsMap();
my $troubledItems = getTroubledItems();
repairBadLocations($troubledItems);
print '##'.DateTime->now()->hms()."## All Items' locations repaired ##\n" if $verbose;





sub repairBadLocations {
    my $troubledItems = shift;

    print '##'.DateTime->now()->hms()."## Starting to repair bad locations ##\n" if $verbose;
    foreach my $item ( @$troubledItems ) {
        my $shelvingLabel = getShelvingLabel($item);
        my $mapping = $reverseLabelMap->{$shelvingLabel} if $shelvingLabel;
        my $location = $item->{location} ? $item->{location} : '';
        my $permanent_location = $item->{permanent_location} ? $item->{permanent_location} : '';

        if ($location && $location ne 'CART' && (!$permanent_location || $permanent_location eq 'CART')) {
            $item->{permanent_location} = $item->{location};
        }
        elsif ($permanent_location && $permanent_location ne 'CART' && !$location) {
            $item->{location} = $item->{permanent_location};
        }
        elsif ($mapping) {
            $item->{location} = $mapping->{location_value};
            $item->{permanent_location} = $mapping->{location_value};
        }
        elsif ($shelvingLabel && !$mapping) {
            warn "Unknown shelvingLabel $shelvingLabel found for itemnumber ".$item->{itemnumber}." !\n";
            next();
        }
        else {
            warn "Unknown location condition. Don't know what to do with this Item!\n".Data::Dumper::Dumper($item)."\n";
            next();
        }
        C4::Items::ModItem($item, undef, $item->{itemnumber});
        print '##'.DateTime->now()->hms().'## Fixing in:'.$item->{itemnumber}.' from loc:'.$location.', per_loc:'.$permanent_location.' with loc:'.$item->{location}.', per_loc:'.$item->{permanent_location}." ##\n" if $verbose;
    }
}


sub getTroubledItems {
    print '##'.DateTime->now()->hms()."## Finding all the troubled Items from DB ##\n" if $verbose;
    my $query = "SELECT itemnumber, homebranch, location, permanent_location, itemcallnumber FROM items WHERE permanent_location IS NULL OR permanent_location = 'CART'";
    my $sth = C4::Context->dbh->prepare($query);
    $sth->execute();
    my $troubledItems = $sth->fetchall_arrayref({});
    return $troubledItems;
}

=head getShelvingLabel

    my $shelvingLabel = getShelvingLabel($item);

Gets the first itemcallnumber element which is the shelvingCode.
Warns if shelvingCode cannot be found.
=cut
sub getShelvingLabel {
    my $item = shift;
    my $itemcallnumber = $item->{itemcallnumber} ? $item->{itemcallnumber} : '';

    my $shelvingLabel;
    if ($itemcallnumber =~ /^(\w+)/) {
        $shelvingLabel = $1;
    }
    else {
        warn "itemnumber ".$item->{itemnumber}." >> COULDN'T FIND shelvingLabel FROM ".$itemcallnumber."\n";
        return undef;
    }
}