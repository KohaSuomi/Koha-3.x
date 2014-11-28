#!/usr/bin/perl

# Copyright 2014-2015 Koha-community
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

use Koha::Deduplicator;

use Getopt::Long qw(:config no_ignore_case);

my ($help, $verbose, $offset, $biblionumber, $matcher_id, $merge);
my $limit = 500;

GetOptions(
    'h|help'           => \$help,
    'v|verbose'        => \$verbose,
    'l|limit:i'        => \$limit,
    'o|offset:i'       => \$offset,
    'b|biblionumber:i' => \$biblionumber,
    'm|matcher:i'      => \$matcher_id,
    'M|merge:s'        => \$merge,
);

my $usage = << 'ENDUSAGE';

This script runs the Koha::Deduplicator from the command line allowing for a much
larger biblio group to be deduplicated.
Finds duplicates for the parametrized group of biblios.

This script has the following parameters :
    -h --help         This help.

    -v --verbose      Prints each biblionumber checked.

    -l --limit        How many biblios to check for duplicates. Is the SQL
                      LIMIT-clause for gathering biblios to deduplicate.

    -o --offset       How many records to skip from the start. Is the SQL
                      OFFSET-clause for gathering biblios to deduplicate.

    -b --biblionumber From which biblionumber (inclusive) to start gathering
                      the biblios to deduplicate. Obsoletes --offset

    -m --matcher      MANDATORY. The matcher to use. References the
                      koha.marc_matcher.matcher_id.

    -M --merge        Automatically merge duplicates. WARNING! This feature can
                      potentially SCREW UP YOUR WHOLE BIBLIO DATABASE! Test
                      the found duplicates well before using this parameter.
                      This feature simply moves all Items, Subscriptions,
                      Acquisitions, Reservations etc. under the new merge target
                      from all matching Biblios and deletes the duplicate
                      Biblios.

                      This parameter has the following sub-modes:
                       'newest' : Uses the Biblio with the biggest timestamp in
                                  Field 005 as the target of the merge.

Examples:

perl deduplicator.pl --match 1 --offset 12000 --limit 500 --verbose
perl deduplicator.pl --match 3 --biblionumber 12313 --limit 500 --verbose
perl deduplicator.pl --match 3 --biblionumber 12313 --limit 500 --verbose --merge newest

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}
if ($merge && $merge eq 'newest') {
    #Merge mode OK
}
elsif ($merge) {
    print "--merge mode $merge not supported. Valid values are [newest]";
    exit;
}

my ($deduplicator, $initErrors) = Koha::Deduplicator->new( $matcher_id, $limit, $offset, $biblionumber, $verbose );
if ($initErrors) {
    print "Errors happened when creating the Deduplicator:\n";
    print join("\n", @$initErrors);
    print "\n";
    print $usage;
    exit;
}
else {
    my $duplicates = $deduplicator->deduplicate();

    foreach my $duplicate (@$duplicates) {
        print 'Match source: '.$duplicate->{biblionumber}.' - '.$duplicate->{title}.' '.$duplicate->{author}."\n";
        foreach my $match (@{$duplicate->{matches}}) {
            print $match->{record_id}.' - '.$match->{score}.' '.$match->{itemsCount}.'  '.$match->{title}.' '.$match->{author}."\n";
        }
        print "\n\n";
    }

    if ($merge && $duplicates) {
        my $errors = $deduplicator->batchMergeDuplicates($duplicates, $merge);
        if ($errors) {
            foreach my $error (@$errors) {
                print $error;
            }
        }
    }
}