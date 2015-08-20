package Koha::AtomicUpdater;

# Copyright Open Source Freedom Fighters
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
use Carp;
use Scalar::Util qw(blessed);
use Try::Tiny;
use Data::Format::Pretty::Console qw(format_pretty);
use Git;

use Koha::Database;
use Koha::Cache;
use Koha::AtomicUpdate;

use base qw(Koha::Objects);

use Koha::Exception::File;
use Koha::Exception::Parse;
use Koha::Exception::BadParameter;

sub type {
    return 'Atomicupdate';
}

sub object_class {
    return 'Koha::AtomicUpdate';
}

sub _get_castable_unique_columns {
    return ['atomicupdate_id'];
}

my $updateOrderFilename = '_updateorder';

sub new {
    my ($class, $params) = @_;

    my $cache = Koha::Cache->new();
    my $self = $cache->get_from_cache('Koha::AtomicUpdater') || {};
    bless($self, $class);

    $self->{verbose} = $params->{verbose} || $self->{verbose} || 0;
    $self->{scriptDir} = $params->{scriptDir} || $self->{scriptDir} || C4::Context->config('intranetdir') . '/installer/data/mysql/atomicupdate/';
    $self->{gitRepo} = $params->{gitRepo} || $self->{gitRepo} || $ENV{KOHA_PATH};

    return $self;
}

=head getAtomicUpdates

    my $atomicUpdates = $atomicUpdater->getAtomicUpdates();

Gets all the AtomicUpdate-objects in the DB. This result should be Koha::Cached.
@RETURNS HASHRef of Koha::AtomicUpdate-objects, keyed with the issue_id
=cut

sub getAtomicUpdates {
    my ($self) = @_;

    my @au = $self->search({});
    my %au; #HASHify the AtomicUpdate-objects for easy searching.
    foreach my $au (@au) {
        $au{$au->issue_id} = $au;
    }
    return \%au;
}

sub addAtomicUpdate {
    my ($self, $params) = @_;
    print "Adding atomicupdate '".($params->{issue_id} || $params->{filename})."'\n" if $self->{verbose} > 2;

    my $atomicupdate = Koha::AtomicUpdate->new($params);
    $atomicupdate->store();
    $atomicupdate = $self->find({issue_id => $atomicupdate->issue_id});
    return $atomicupdate;
}

sub removeAtomicUpdate {
    my ($self, $issueId) = @_;
    print "Deleting atomicupdate '$issueId'\n" if $self->{verbose} > 2;

    my $atomicupdate = $self->find({issue_id => $issueId});
    if ($atomicupdate) {
        $atomicupdate->delete;
        print "Deleted atomicupdate '$issueId'\n" if $self->{verbose} > 2;
    }
    else {
        Koha::Exception::BadParameter->throw(error => __PACKAGE__."->removeIssueFromLog():> No such Issue '$issueId' stored to the atomicupdates-table");
    }
}

sub listToConsole {
    my ($self) = @_;
    my @stringBuilder;

    my @atomicupdates = $self->search({});
    foreach my $au (@atomicupdates) {
        push @stringBuilder, $au->unblessed();
    }
    return Data::Format::Pretty::Console::format_pretty(\@stringBuilder);
}

sub listPendingToConsole {
    my ($self) = @_;
    my @stringBuilder;

    my $atomicUpdates = $self->getPendingAtomicUpdates();
    foreach my $key (sort keys %$atomicUpdates) {
        my $au = $atomicUpdates->{$key};
        push @stringBuilder, $au->unblessed();
    }
    return Data::Format::Pretty::Console::format_pretty(\@stringBuilder);
}

sub getPendingAtomicUpdates {
    my ($self) = @_;

    my %pendingAtomicUpdates;
    my $atomicupdateFiles = $self->_getValidAtomicUpdateScripts();
    my $atomicUpdatesDeployed = $self->getAtomicUpdates();
    foreach my $key (keys(%$atomicupdateFiles)) {
        my $au = $atomicupdateFiles->{$key};
        unless ($atomicUpdatesDeployed->{$au->issue_id}) {
            #This script hasn't been deployed.
            $pendingAtomicUpdates{$au->issue_id} = $au;
        }
    }
    return \%pendingAtomicUpdates;
}

=head applyAtomicUpdates

    my $atomicUpdater = Koha::AtomicUpdater->new();
    my $appliedAtomicupdates = $atomicUpdater->applyAtomicUpdates();

Checks the atomicupdates/-directory for any not-applied update scripts and
runs them in the order specified in the _updateorder-file in atomicupdate/-directory.

@RETURNS ARRAYRef of Koha::AtomicUpdate-objects deployed on this run
=cut

sub applyAtomicUpdates {
    my ($self) = @_;

    my %appliedUpdates;

    my $atomicUpdates = $self->getPendingAtomicUpdates();
    my $updateOrder = $self->getUpdateOrder();
    foreach my $issueId ( @$updateOrder ) {
        my $atomicUpdate = $atomicUpdates->{$issueId};
        next unless $atomicUpdate; #Not each ordered Git commit necessarily have a atomicupdate-script.

        my $filename = $atomicUpdate->filename;
        print "Applying file '$filename'\n" if $self->{verbose} > 2;

        if ( $filename =~ /\.sql$/ ) {
            my $installer = C4::Installer->new();
            my $rv = $installer->load_sql( $self->{scriptDir}.'/'.$filename ) ? 0 : 1;
        } elsif ( $filename =~ /\.(perl|pl)$/ ) {
            do $self->{scriptDir}.'/'.$filename;
        }

        $atomicUpdate->store();
        $appliedUpdates{$issueId} = $atomicUpdate;
        print "File '$filename' applied\n" if $self->{verbose} > 2;
    }

    #Check that we have actually applied all the updates.
    my $stillPendingAtomicUpdates = $self->getPendingAtomicUpdates();
    if (scalar(%$stillPendingAtomicUpdates)) {
        my @issueIds = sort keys %$stillPendingAtomicUpdates;
        print "Warning! After upgrade, the following atomicupdates are still pending '@issueIds'\n Try rebuilding the atomicupdate-scripts update order from the original Git repository.\n";
    }

    return \%appliedUpdates;
}

=head _getValidAtomicUpdateScripts

@RETURNS HASHRef of Koha::AtomicUpdate-objects, of all the files
                in the atomicupdates/-directory that can be considered valid.
                Validity is currently conforming to the naming convention.
                Keys are the issue_id of atomicupdate-scripts
                Eg. {'Bug8584' => Koha::AtomicUpdate,
                     ...
                    }
=cut

sub _getValidAtomicUpdateScripts {
    my ($self) = @_;

    my %atomicUpdates;
    opendir( my $dirh, $self->{scriptDir} );
    foreach my $file ( sort readdir $dirh ) {
        print "Looking at file $file\n" if $self->{verbose} > 2;

        my $atomicUpdate;
        try {
            $atomicUpdate = Koha::AtomicUpdate->new({filename => $file});
        } catch {
            if (blessed($_)) {
                if ($_->isa('Koha::Exception::File') || $_->isa('Koha::Exception::Parse')) {
                    #We can ignore filename validation issues, since the directory has
                    #loads of other types of files as well. Like README . ..
                }
                else {
                    $_->rethrow();
                }
            }
            else {
                die $_; #Rethrow the unknown Exception
            }
        };
        next unless $atomicUpdate;

        $atomicUpdates{$atomicUpdate->issue_id} = $atomicUpdate;
    }
    return \%atomicUpdates;
}

=head getUpdateOrder

    $atomicUpdater->getUpdateOrder();

@RETURNS ARRAYRef of Strings, IssueIds ordered from the earliest to the newest.
=cut

sub getUpdateOrder {
    my ($self) = @_;

    my $updateOrderFilepath = $self->{scriptDir}."/$updateOrderFilename";
    open(my $FH, "<:encoding(UTF-8)", $updateOrderFilepath) or die "Koha::AtomicUpdater->_saveAsUpdateOrder():> Couldn't open the updateOrderFile for reading\n$!\n";
    my @updateOrder = map {chomp($_); $_;} <$FH>;
    close $FH;
    return \@updateOrder;
}

=head

    my $issueIdOrder = Koha::AtomicUpdater->buildUpdateOrderFromGit(10000);

Creates a update order file '_updateorder' for atomicupdates to know which updates come before which.
This is a simple way to make sure the atomicupdates are applied in the correct order.
The update order file is by default in your $KOHA_PATH/installer/data/mysql/atomicupdate/_updateorder

This requires a Git repository to be in the $ENV{KOHA_PATH} to be effective.

@PARAM1 Integer, How many Git commits to include to the update order file,
                 10000 is a good default.
@RETURNS ARRAYRef of Strings, The update order of atomicupdates from oldest to newest.
=cut

sub buildUpdateOrderFromGit {
    my ($self, $gitCommitsCount) = @_;

    my %orderedCommits; #Store the commits we have ordered here, so we don't reorder any followups.
    my @orderedCommits;

    my $i = 0; #Index of array where we push issue_ids
    my $commits = $self->_getGitCommits($gitCommitsCount);
    foreach my $commit (reverse @$commits) {

        my ($commitHash, $commitTitle) = $self->_parseGitOneliner($commit);
        unless ($commitHash && $commitTitle) {
            next();
        }

        my $issueId;
        try {
            $issueId = Koha::AtomicUpdate->getIssueIdentifier($commitTitle);
        } catch {
            if (blessed($_)) {
                if($_->isa('Koha::Exception::Parse')) {
                    #Silently ignore parsing errors
                    print "Koha::AtomicUpdater->buildUpdateOrderFromGit():> Couldn't parse issue_id from Git commit title '$commitTitle'.\n"
                                    if $self->{verbose} > 1;
                }
                else {
                    $_->rethrow();
                }
            }
            else {
                die $_;
            }
        };
        next unless $issueId;

        if ($orderedCommits{ $issueId }) {
            next();
        }
        else {
            $orderedCommits{ $issueId } = $issueId;
            $orderedCommits[$i] = $issueId;
            $i++;
        }
    }

    $self->_saveAsUpdateOrder(\@orderedCommits);
    return \@orderedCommits;
}

sub _getGitCommits {
    my ($self, $count) = @_;
    my $repo = Git->repository(Directory => $self->{gitRepo});

    #We can read and print 10000 git commits in less than three seconds :) good Git!
    my @commits = $repo->command('show', '--pretty=oneline', '--no-patch', '-'.$count);
    return \@commits;
}

sub _parseGitOneliner {
    my ($self, $gitLiner) = @_;

    my ($commitHash, $commitTitle) = ($1, $2) if $gitLiner =~ /^(\w{40}) (.+)$/;
    unless ($commitHash && $commitTitle) {
        print "Koha::AtomicUpdater->parseGitOneliner():> Couldn't parse Git commit '$gitLiner' to hash and title.\n"
                        if $self->{verbose} > 1;
        return();
    }
    return ($commitHash, $commitTitle);
}

sub _saveAsUpdateOrder {
    my ($self, $orderedUpdates) = @_;

    my $updateOrderFilepath = $self->{scriptDir}."/$updateOrderFilename";
    my $text = join("\n", @$orderedUpdates);
    open(my $FH, ">:encoding(UTF-8)", $updateOrderFilepath) or die "Koha::AtomicUpdater->_saveAsUpdateOrder():> Couldn't open the updateOrderFile for writing\n$!\n";
    print $FH $text;
    close $FH;
}

1;
