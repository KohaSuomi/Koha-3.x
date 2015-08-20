#!/usr/bin/perl
#
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
#

use Modern::Perl;
use Getopt::Long;

use C4::Context;

use Koha::AtomicUpdater;

my $verbose = 0;
my $help = 0;
my $apply = 0;
my $remove = '';
my $insert = '';
my $list = 0;
my $pending = 0;
my $directory = '';
my $git = '';

GetOptions(
    'v|verbose:i'       => \$verbose,
    'h|help'            => \$help,
    'a|apply'           => \$apply,
    'd|directory:s'     => \$directory,
    'r|remove:s'        => \$remove,
    'i|insert:s'        => \$insert,
    'l|list'            => \$list,
    'p|pending'         => \$pending,
    'g|git:s'           => \$git,
);

my $usage = << 'ENDUSAGE';

Runs all the not-yet-applied atomicupdate-scripts and sql in the
atomicupdates-directory, in the order specified by the _updateorder-file.

This script uses koha.atomicupdates-table to see if the update has already been
applied.

Also acts as a gateway to CRUD the koha.database_updates-table.

    -v --verbose        Integer, 1 is not so verbose, 3 is maximally verbose.
    -h --help           Flag, This nice help!
    -a --apply          Flag, Apply all the pending atomicupdates from the
                        atomicupdates-directory.
    -d --directory      Path, From which directory to look for atomicupdate-scripts.
                        Defaults to '$KOHA_PATH/installer/data/mysql/atomicupdate/'
    -r --remove         String, Remove the upgrade entry from koha.database_updates
                        eg. --remove "Bug71337"
    -i --insert         Path, Add an upgrade log entry for the given atomicupdate-file.
                        Useful to revert an accidental --remove -operation or for
                        testing.
                        eg. -i installer/data/mysql/atomicupdate/Bug5453-Example.pl
    -l --list           Flag, List all entries in the koha.database_updates-table.
                        This typically means all applied atomicupdates.
    -p --pending        Flag, List all pending atomicupdates from the
                        atomicupdates-directory.
    -g --git            Path, Build the update order from the Git repository given,
                        or default to the Git repository in $KOHA_PATH.
                        Eg. --git 1, to build with default values, or
                            --git /tmp/kohaclone/ to look for another repository

EXAMPLES:

    atomicupdate.pl -g 1 -a

Looks for the Git repository in $KOHA_PATH, parses the issue/commit identifiers
from the top 10000 commits and generates the _updateorder-file to tell in which
order the atomicupdates-scripts are executed.
Then applies all pending atomicupdate-scripts in the order (oldest to newest)
presented in the Git repository.


    atomicupdate --apply -d /home/koha/kohaclone/installer/data/mysql/atomicupdate/

Applies all pending atomicupdate-scripts from the given directory. If the file
'_updateorder' is not present, it must be first generated, for example with the
--git 1 argument.

UPDATEORDER:

When deploying more than one atomicupdate, it is imperative to know in which order
the updates are applied. Atomicupdates can easily depend on each other and fail in
very strange and hard-to-debug -ways if the prerequisite modifications are not
in effect.
The correct update order is defined in the atomicupdates/_updateorder-file. This is
a simple list of issue/commit identifiers, eg.

    Bug5454
    Bug12432
    Bug3218
    #45

This file is most easily generated directly from the original Git repository, since
the order in which the Commits have been introduced most definetely is the order
they should be applied.
When deploying the atomicupdates to production environments without the
Git repository, the _updateorder file must be copied along the atomicupdate-scripts.

P.S. Remember to put atomicupdate/_updateorder to your .gitignore

ENDUSAGE

if ( $help ) {
    print $usage;
    exit;
}

my $atomicupdater = Koha::AtomicUpdater->new({verbose => $verbose,
                                              scriptDir => $directory,
                                              gitRepo => (length($git) == 1) ? '' : $git});

if ($git) {
    $atomicupdater->buildUpdateOrderFromGit(10000);
}
if ($remove) {
    $atomicupdater->removeAtomicUpdate($remove);
}
if ($insert) {
    $atomicupdater->addAtomicUpdate({filename => $insert});
}
if ($list) {
    print $atomicupdater->listToConsole();
}
if ($pending) {
    print $atomicupdater->listPendingToConsole();
}
if ($apply) {
    $atomicupdater->applyAtomicUpdates();
}
