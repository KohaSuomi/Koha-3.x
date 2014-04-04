#!/usr/bin/perl
#-----------------------------------
# Copyright 2008 LibLime
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

=head1 NAME

longoverdue.pl  cron script to set lost statuses on overdue materials.
                Execute without options for help.

=cut

use Modern::Perl;
use POSIX;

use C4::Context;
use Getopt::Long;

## Setting command line parameters ##
my $shortLoanExpirationTime_days = 90;
my $help = 0;
my $verbose = 0;

GetOptions(
    's|shortLoanExp=s%' => \$shortLoanExpirationTime_days,
    'h|help'          => \$help,
    'v|verbose'       => \$verbose,
);

my $usage = <<ENDUSAGE;
removeShortLoanStatus.pl :
Removes the collection code from items that have been available for more then [--expiration] days.

This script takes the following parameters :

    --shortLoanExp | -s    The number of days from arrival to a library, the shortloan items stay in the shortloan state.
                           Defaults to 90 days.

    --help | -h            This help!!

    --verbose | v          verbose.

ENDUSAGE

print $usage if $help;

## Command line params OK starting with the core script ##



# Init timestamp variables
my $day = 60*60*24;


my $dbh = C4::Context->dbh;

#SS Short loan SSS
## Remove ccode from all items which have a ccode LYLA (Lyhytlaina) and have been available for more than 3 months.
##   This releases their duedate calculations to follow the given guidelines.
sub revertShortLoansToDefault {
    my $expirationTime = time - ($day * $shortLoanExpirationTime_days);
    $expirationTime = strftime("%Y-%m-%d", localtime( $expirationTime ));
    print "Shortloans Date acquired (items.accessioned) later than $expirationTime will be reverted to default\n" if $verbose;

    my $sql = "UPDATE items INNER JOIN reserves ON items.itemnumber = reserves.itemnumber SET items.ccode = NULL WHERE items.ccode = 'LYLA' AND items.dateaccessioned < ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute( $expirationTime );

    if ( $sth->err ) {
        #Le fuuu there is a PROBLEMMMMMMMMM!!!!!!!!!!
        warn "ERROR! return code: ". $sth->err . " error msg: " . $sth->errstr . "\n";
    }
}

revertShortLoansToDefault();