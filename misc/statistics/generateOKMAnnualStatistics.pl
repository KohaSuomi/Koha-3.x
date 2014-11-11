#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long;

use C4::Context();
use C4::Branch;
use C4::OPLIB::OKM;

my $help;
my $thisYear = (localtime(time))[5] + 1900; #Get the current year;
my ($limit, $rebuild, $asCsv, $asHtml);

GetOptions(
    'h|help'        => \$help,
    'a|year'        => \$thisYear,
    'l|limit:i'     => \$limit,
    'r|rebuild'     => \$rebuild,
    'html'          => \$asHtml,
    'csv'           => \$asCsv,
);
my $usage = << 'ENDUSAGE';

This script generates the OKM annual statistics and prints them as a csv to STDOUT.
Running this script will take around half an hour depending on the HDD performance.

This script has the following parameters :
    -h --help:    this message
    -l --limit:   an SQL LIMIT -clause for testing purposes
    -a --year:    The year from which to get statistics from. Defaults to the current year.
    -r --rebuild: Rebuild OKM statistics. By default, if statistics have been generated for
                  the given year, they are retrieved from the DB.
    --html:       Print as an HTML table
    --csv:        Print as an .csv

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

generateStatistics();

sub generateStatistics {

    my $okm;
    if (not($rebuild)) {
        print "#Using existing statistics.#\n";
        $okm = C4::OPLIB::OKM::Retrieve( $thisYear );
    }
    if (not($okm)) {
        print "#Regenerating statistics. This will take some time!#\n";
        $okm = C4::OPLIB::OKM->new( $thisYear, $limit );
        $okm->save();
    }

    my $errors = $okm->verify();
    if ($asCsv) {
        print $okm->asCsv();
    }
    if ($asHtml) {
        print $okm->asHtml();
    }
    foreach (@$errors) {print $_."\n";}
}