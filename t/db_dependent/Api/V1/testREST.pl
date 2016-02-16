#!/usr/bin/perl

# Copyright 2016 KohaSuomi
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Test::More;
use Getopt::Long qw(:config no_ignore_case);

use t::lib::Swagger2TestRunner;

# These are defaults for command line options.
my @testKeywords;
my $help    = 0;
my $verbose = 0;
my $verb    = '';

GetOptions(
            'h|help'          => \$help,
            'k|keywords=s{,}' => \@testKeywords,
            'v|verbose:i'     => \$verbose,
            'V|verb:s'        => \$verb,
       );

my $helpText = <<HELP;

perl t/db_dependent/Api/V1/testREST.pl

Triggers all tests for all REST API endpoints for V1.
See. t::lib::Swagger2TestRunner->new() for parameter descriptions.

  -h --help        This help text.

  -v --verbose     Verbosity of the tests and the test runner debugging information
                   1, expose Swagger error messages.
                   2, more verbose details about executed tests
                   3, exposes internal debug messages, like API Key Auth hashing.

  -k --keywords    A comma-separated list of selectors used to test only a subset of REST
                   endpoints. Different selectors are:
                    \@
                      eg. \@/api/v1/borrowers/{borrowernumber}
                      #Matches only the given endpoint

                    ^
                      eg. ^borrowers
                      #Excludes endpoints that contain "borrowers"
                    nothing
                      eg. borrowers
                      #Includes all endpoints that contain the following word

                    You can combine the selectors as logical AND-statements, eg.
                      -k borrowers biblios
                      #Include all endpoints containing borrowers and biblios
                      -k "^borrowers" biblios
                      #Exclude all endpoints containing borrowers and include
                      #biblios. Would match this endpoint:
                      #  "/api/v1/biblios/author"
                      #but not his one
                      #  "/api/v1/biblios/statistics/borrowers"

    -V --verb       Match only the given HTTP verb (GET, POST, DELETE, ...)

HELP


if ($help) {
    print $helpText;
    exit;
}

$ENV{KOHA_REST_API_DEBUG} = $verbose;

my $testRunner = t::lib::Swagger2TestRunner->new({testKeywords => \@testKeywords, verb => $verb});
$testRunner->testREST();
