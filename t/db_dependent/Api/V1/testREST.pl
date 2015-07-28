#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Getopt::Long;

use t::lib::Swagger2TestRunner;

# These are defaults for command line options.
my @testKeywords;
my $help    = 0;

GetOptions(
            'h|help'          => \$help,
            'k|keywords=s{,}' => \@testKeywords,
       );

my $helpText = <<HELP;

perl t/db_dependent/Api/V1/testREST.pl

Triggers all tests for all REST API endpoints for V1.
See. t::lib::Swagger2TestRunner->new() for parameter descriptions.

  --help        This help text.

HELP


if ($help) {
    print $helpText;
    exit;
}


my $testRunner = t::lib::Swagger2TestRunner->new({testKeywords => \@testKeywords});
$testRunner->testREST();
