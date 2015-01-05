#!/usr/bin/perl

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

use Modern::Perl;

use open qw( :std :encoding(UTF-8) );
binmode( STDOUT, ":encoding(UTF-8)" );

use C4::Context;
use C4::Members;

use Getopt::Long qw(:config no_ignore_case);

my ($help, $verbose, $confirm, $year);

GetOptions(
    'h|help'           => \$help,
    'v|verbose'        => \$verbose,
    'c|confirm'        => \$confirm,
    'y|year:i'         => \$year,
);

my $usage = << 'ENDUSAGE';

This script adds a manual debarment for all borrowers who have outstanding overdue fines during the given year.
Used to block borrowers who haven't paid their fines during the previous year when dealing with the turn of the
year.

This is meant to be ran as a cronjob, and must be ran with the following cronjob configuration:
05 00 01 01 *   $KOHA_CRONJOB_TRIGGER cronjobs/turnoftheyearBlockBorrowersWithFines.pl -v -y $(($(date +%Y)-1)) -c
That runs this script at 01-01-YYYYT00:05:00 every year, targeting the previous year.

This script has the following parameters :
    -h --help         This help.

    -v --verbose      Nice verbosity to flood your log!

    -c --confirm      You must set this flag to acknowledge that your borrowers will get barred and possibly
                      causing havok and mayhem! Read the help file!

    -y --year         You must give the year to check. For ex with --year=2014, all borrowers with
                      overdues due sometime during 2014 will be debarred, if those overdues haven't
                      been paid. Take note that if you were to run this script say, 10.10.2014, all
                      borrowers would get debarred, if they have even 1 cent of overdue fines.

Examples:

perl turnoftheyearBlockBorrowersWithFines.pl --verbose --year 2014
                      Adds a debarment for all borrowers who have unpaid overdue fines for Items whose
                      duedate is sometime 2014.

ENDUSAGE

if ($help || not($confirm)) {
    print $usage;
    print "RTFM\n" unless $confirm;
    exit;
}




use C4::Context;
use Koha::Borrower::Debarments;

my $dbh = C4::Context->dbh;

print "## Removing all turnofyear debarments for the given year! ##\n" if $verbose;
my $delquery = "DELETE FROM borrower_debarments WHERE ".
               "type='MANUAL' AND comment LIKE '%Vuodenvaihteessa $year-".($year+1)." maksuja maksamatta! Tili estetty.%'";
my $delsth = $dbh->prepare($delquery);
$delsth->execute();


print "## Getting all the accountlines! ##\n" if $verbose;
my $query = "SELECT * FROM accountlines WHERE description REGEXP '[0-9][0-9].[0-9][0-9].2014' AND amountoutstanding > 0 ORDER BY accountlines_id DESC";
my $sth   = $dbh->prepare($query);
$sth->execute();
my $als = $sth->fetchall_arrayref({});


my %preparedDebarments;


print '## Getting all accountlines which have /\d\d\.\d\d\.2014/ in their description and amountoutstanding > 0 ##'."\n" if $verbose;
foreach my $al (@$als) {

    my $in = $al->{itemnumber} ? $al->{itemnumber} : '';
    print 'Found id '.$al->{accountlines_id}.', bn '.$al->{borrowernumber}.', in '.$in.
          ', ao '.$al->{amountoutstanding}."\n"
          if $verbose;

    my $bn = $al->{borrowernumber};
    my $debarment;
    if ($preparedDebarments{$bn}) {
        $debarment = $preparedDebarments{$bn};
        $debarment->{comment} .= "\n".$al->{description};
    }
    else {
        $debarment = {};
        $preparedDebarments{$bn} = $debarment;
        $debarment->{comment} = "Vuodenvaihteessa $year-".($year+1)." maksuja maksamatta! Tili estetty.\n".$al->{description};
    }
}
print "## Adding the prepared debarments! ##\n" if $verbose;
foreach my $bn (sort keys %preparedDebarments) {
    my $debarment = $preparedDebarments{$bn};
    print 'Debaring borrowernumber '.$bn."\n" if $verbose;
    Koha::Borrower::Debarments::AddDebarment({
                borrowernumber => $bn,
                comment => $debarment->{comment},
    });
}
