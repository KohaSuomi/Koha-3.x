#!/usr/bin/perl

# Copyright 2009-2010 Kyle Hall
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

use Modern::Perl;

use Getopt::Long;
use C4::Reserves qw(CancelExpiredReserves);

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

# These are defaults for command line options.
my $verbose = 0;
my $help    = 0;


GetOptions(
    'h|help|?'                     => \$help,
    'v|verbose:i'                    => \$verbose,
);

if ($help) {
    die <<HEAD;
This scripts cancels all expired hold requests and all holds that have expired
their last pickup date.

    -v --verbose <level>    Prints more verbose information.
                            Supported levels, 0,1,2,3
HEAD
}

print CancelExpiredReserves($verbose);
