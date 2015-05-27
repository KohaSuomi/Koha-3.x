#!/usr/bin/perl

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
use Test::More;
use Test::BDD::Cucumber::StepFile;
use Test::BDD::Cucumber::Loader;
use Test::BDD::Cucumber::Harness::TestBuilder;
use Test::BDD::Cucumber::Model::TagSpec;

use Getopt::Long qw(:config no_ignore_case);

my $help;
my $featureRegexp;
my $verbose;
my @tags;

GetOptions(
    'h|help'                      => \$help,
    'f|featureRegexp:s'           => \$featureRegexp,
    'v|verbose:i'                 => \$verbose,
    't|tags:s'                    => \@tags,
);

my $usage = <<USAGE;

perl runCucumberTests.t --verbose 2 --featureRegexp "overdues" --tags \@overdues

Executes all Cucumber tests. You can narrow down the tests to run using --tags
and --featureRegexp, and make various testing configurations with them.

  --tags                See https://github.com/cucumber/cucumber/wiki/Tags
                        ~\@tag is not supported, only \@tag.
                        Only runs the scenarios/features these tags are given to.
                        This is quite useful when developing, because you can
                        easily narrow down which scenarios to execute amidst
                        features containing lots of expensive tests.

  --featureRegexp       Will run only features whose feature description's first
                        line matches the given escaped regexp.
                        Prefer using tags if possible, since that is the Cucumber-way.

USAGE

if ($help) {
    print $usage;
    exit 0;
}

if ($verbose) {
    $ENV{CUCUMBER_VERBOSE} = $verbose;
}

#Set the default Koha context
use C4::Context;
C4::Context->_new_userenv('DUMMY SESSION');
C4::Context->set_userenv(0,0,0,'firstname','surname', 'CPL', 'Library 1', 0, '', '');


######  #  #  #  #  #  #  #  ######
###   Run the Cucumber tests.   ###
######  #  #  #  #  #  #  #  ######
my ( $executor, @features ) = Test::BDD::Cucumber::Loader->load( '.' );

if ($featureRegexp) {
    #Pick only the needed feature
    my @filteredFeatures;
    for (my $i=0 ; $i<@features ; $i++) {
        my $feature = $features[$i];
        push @filteredFeatures, ($features[$i]) if $feature->name() =~ m/$featureRegexp/i;
    }
    @features = @filteredFeatures;
}

my $tagSet;
if (scalar(@tags)) {
    #Load given tags.
    for (my $i=0 ; $i<@tags ; $i++) {
        $tags[$i] =~ s/[@]//;
    }
    $tagSet = Test::BDD::Cucumber::Model::TagSpec->new({
       tags => [ and => @tags ],
    });
}

my $harness = Test::BDD::Cucumber::Harness::TestBuilder->new({});
$executor->execute( $_, $harness, $tagSet ) for @features;
done_testing;