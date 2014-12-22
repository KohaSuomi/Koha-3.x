#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long;

use C4::Context();
use C4::Branch;
use C4::OPLIB::OKM;

my $help;
my ($limit, $rebuild, $asCsv, $asHtml, $individualBranches, $timeperiod);

GetOptions(
    'h|help'         => \$help,
    'l|limit:i'      => \$limit,
    'r|rebuild'      => \$rebuild,
    'i|individual:s' => \$individualBranches,
    't|timeperiod:s' => \$timeperiod,
    'html'           => \$asHtml,
    'csv'            => \$asCsv,
);
my $usage = << 'ENDUSAGE';

This script generates the OKM annual statistics and prints them as a csv to STDOUT.
Running this script will take around half an hour depending on the HDD performance.

This script has the following parameters :

    -h --help       this message

    -l --limit      an SQL LIMIT -clause for testing purposes

    -t --timeperiod The timeperiod definition. Supported values are:
                      1. "YYYY-MM-DD - YYYY-MM-DD" (start to end, inclusive)
                      2. "YYYY" (desired year)
                      3. "MM" (desired month, of the current year)
                      4. "lastyear" (Calculates the whole last year)
                      5. "lastmonth" (Calculates the whole previous month)
                    Kills the process if no timeperiod is defined or if it is unparseable!

    -r --rebuild    Rebuild OKM statistics. By default, if statistics have been generated for
                    the given year, they are retrieved from the DB.

    -i --individual Individual branches. Instead of using the OKM library groups, we can generate
                    statistics for individual branches. This is a comma-separated list of branchcodes.
                    If '-i *' is given, then all branches are accounted for.
                    USAGE: '-i JOE_JOE,JOE_LIP,JOE_RAN,JOE_KAR'

    --html          Print as an HTML table

    --csv           Print as an .csv

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

generateStatistics();

sub generateStatistics {

    my $okm;
    if (not($rebuild)) {
        $okm = C4::OPLIB::OKM::Retrieve( undef, $timeperiod, $individualBranches );
        print "#Using existing statistics.#\n" if $okm;
    }
    if (not($okm)) {
        print "#Regenerating statistics. This will take some time!#\n";
        $okm = C4::OPLIB::OKM->new( $timeperiod, $limit, $individualBranches );
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