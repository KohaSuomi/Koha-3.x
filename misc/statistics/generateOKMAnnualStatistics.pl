#!/usr/bin/perl

use Modern::Perl;
use open qw( :std :encoding(UTF-8) );
binmode( STDOUT, ":encoding(UTF-8)" );

use Getopt::Long;

use C4::Context();
use C4::Branch;
use C4::OPLIB::OKM;

my $help;
my ($limit, $rebuild, $asCsv, $asHtml, $individualBranches, $timeperiod, $rebuildAllStatistics, $verbose, $juvenileShelvingLocations);

GetOptions(
    'h|help'           => \$help,
    'l|limit:i'        => \$limit,
    'r|rebuild'        => \$rebuild,
    'i|individual:s'   => \$individualBranches,
    't|timeperiod:s'   => \$timeperiod,
    'html'             => \$asHtml,
    'csv'              => \$asCsv,
    'rebuildAllStats:s'=> \$rebuildAllStatistics,
    'v|verbose'        => \$verbose,
    'juvenileShelLocs:s' => \$juvenileShelvingLocations,
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
                    If "-i '_A'" is given, then all branches are accounted for.
                    USAGE: '-i JOE_JOE,JOE_LIP,JOE_RAN,JOE_KAR'

    --html          Print as an HTML table

    --csv           Print as an .csv

    -v --verbose    More chatty script.

    --rebuildAllStats
                    Creates statistics for the whole year, and for each month separately, for the
                    following groupings. One where the OKM-librarygroups have been
                    defined, and the other where all branches are their separate statistical rows.
                    Also give the year you want to statisticize.
                    Example: "generateOKMAnnualStatistics.pl --rebuildAllStats 2014"
    --juvenileShelLocs
                    Overrides the shelving locations considered to contain juvenile material. By Default OKM-module
                    considers items as juvenile material if they are in shelving locations with an
                    koha.authorised_values.imageurl =~ /okm_juvenile/.
                    This parameter is a .csv-row with each element as a shelving location code
                    'LAP,NUO,NUOV,[...]'
                    or undef to preserve default operation

EXAMPLES:

    ./generateOKMAnnualStatistics.pl --rebuildAllStats 2014 --juvenileShelLocs 'KUV,LAP,LAK,LVA,NUO,NUA,NUV' -v --csv
    ./generateOKMAnnualStatistics.pl --timeperiod '2014-01-01 - 2014-02-15' -l 1000 -r -v --csv

    #Generate monthly reports, using the bash 'date' to generate the previous month for OKM branchcategories
    ./generateOKMAnnualStatistics.pl --timeperiod $(($(date +%m)-1)) -r -v
    #For all branches
    ./generateOKMAnnualStatistics.pl --timeperiod $(($(date +%m)-1)) --individual '_A' -r -v

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

if ($rebuildAllStatistics) {
    rebuildAllStatistics();
}
else {
    generateStatistics();
}

sub generateStatistics {

    my $okm;
    if (not($rebuild)) {
        $okm = C4::OPLIB::OKM::Retrieve( undef, $timeperiod, $individualBranches );
        print "#Using existing statistics.#\n" if $okm;
    }
    if (not($okm)) {
        print "#Regenerating statistics. This will take some time!#\n";
        $okm = C4::OPLIB::OKM->new( $timeperiod, $limit, $individualBranches, undef, $verbose, $juvenileShelvingLocations );
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

sub rebuildAllStatistics {

    my ($yearStart, $yearEnd) = C4::OPLIB::OKM::StandardizeTimeperiodParameter($rebuildAllStatistics);
    my $biblioCache = {}; #Store the humongous bibliocache used to calculate one round of OKM statistics. Calculating it takes minutes.

    ##Calculate OKM statistics for all branches for given year.
    print '#'.DateTime->now()->iso8601().'# Building statistics for all branches, year '.$yearStart->year()." #\n";
    my $okm = C4::OPLIB::OKM->new( $yearStart->year(), $limit, '_A', $biblioCache, $verbose, $juvenileShelvingLocations );
    $okm->save() if $okm;

    ##Calculate OKM statistics for OKM groups for given year.
    print '#'.DateTime->now()->iso8601().'# Building statistics for OKM librarygroups, year '.$yearStart->year()." #\n";
    $okm = C4::OPLIB::OKM->new( $yearStart->year(), $limit, undef, $biblioCache, $verbose, $juvenileShelvingLocations );
    $okm->save() if $okm;

    ##Calculate OKM statistics for all branches for each month.
    my $startMonth = $yearStart->clone();
    do {
        my $endMonth = DateTime->last_day_of_month( year  => $startMonth->year(),
                                                    month => $startMonth->month(),
                                                    time_zone => $startMonth->time_zone(),
                                                  );
        my $timeperiod = $startMonth->iso8601().' - '.$endMonth->iso8601();
        print '#'.DateTime->now()->iso8601().'# Building statistics for all branches, '.$startMonth->month_name()." #\n";
        my $okm = C4::OPLIB::OKM->new( $timeperiod, $limit, '_A', $biblioCache, $verbose, $juvenileShelvingLocations );
        $okm->save() if $okm;

        $startMonth = $startMonth->add(months => 1);
    } while ($yearStart->year() == $startMonth->year());

    ##Calculate OKM statistics for OKM librarygroups for each month.
    $startMonth = $yearStart->clone();
    do {
        my $endMonth = DateTime->last_day_of_month( year  => $startMonth->year(),
                                                    month => $startMonth->month(),
                                                    time_zone => $startMonth->time_zone(),
                                                  );
        my $timeperiod = $startMonth->iso8601().' - '.$endMonth->iso8601();
        print '#'.DateTime->now()->iso8601().'# Building statistics for OKM librarygroups, '.$startMonth->month_name()." #\n";
        my $okm = C4::OPLIB::OKM->new( $timeperiod, $limit, undef, $biblioCache, $verbose, $juvenileShelvingLocations );
        $okm->save() if $okm;

        $startMonth = $startMonth->add(months => 1);
    } while ($yearStart->year() == $startMonth->year());
}
