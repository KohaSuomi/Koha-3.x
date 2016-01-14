package Koha::AtomicUpdate;

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
use File::Basename;

use Koha::Database;

use base qw(Koha::Object);

use Koha::Exception::BadParameter;

sub type {
    return 'Atomicupdate';
}

=head new

    my $atomicUpdate = Koha::AtomicUpdate->new({filename => 'Bug54321-FixItPlease.pl'});

Creates a Koha::AtomicUpdate-object from the given parameters-HASH
@PARAM1 HASHRef of object parameters:
        'filename' => MANDATORY, The filename of the atomicupdate-script without the path-component.
        'issue_id' => OPTIONAL, the desired issue_id. It is better to let the module
                                find this from the filename, but is useful for testing purposes.
@RETURNS Koha::AtomicUpdate-object
@THROWS Koha::Exception::Parse from getIssueIdentifier()
@THROWS Koha::Exception::File from _validateFilename();
=cut

sub new {
    my ($class, $params) = @_;
    $class->_validateParams($params);

    my $self = {};
    bless($self, $class);
    $self->set($params);
    return $self;
}

sub _validateParams {
    my ($class, $params) = @_;

    my @mandatoryParams = ('filename');
    foreach my $mp (@mandatoryParams) {
        Koha::Exception::BadParameter->throw(
            error => "$class->_validateParams():> Param '$mp' must be given.")
                unless($params->{$mp});
    }
    $params->{filename} = $class->_validateFilename($params->{filename});

    $params->{issue_id} = $class->getIssueIdentifier($params->{issue_id} || $params->{filename});
}

=head _validateFilename

Makes sure the given file is a valid AtomicUpdate-script.
Currently simply checks for naming convention and file suffix.

NAMING CONVENTION:
    Filename must contain one of the unique issue identifier prefixes from this
    list @allowedIssueIdentifierPrefixes immediately followed by the numeric
    id of the issue, optionally separated by any of the following [ :-]
    Eg. Bug-45453, #102, #:53

@PARAM1 String, filename of validatable file, excluding path.
@RETURNS String, the koha.atomicupdates.filename if the given file is considered a well formed update script.
                 Removes the full path if present and returns only the filename component.

@THROWS Koha::Exception::File, if the given file doesn't have a proper naming convention

=cut

sub _validateFilename {
    my ($self, $fileName) = @_;

    Koha::Exception::File->throw(error => __PACKAGE__."->_validateFilename():> Filename '$fileName' has unknown suffix")
            unless $fileName =~ /\.(sql|perl|pl)$/;  #skip other files

    $fileName = File::Basename::basename($fileName);

    return $fileName;
}

=head getIssueIdentifier

Extracts the unique issue identifier from the atomicupdate DB upgrade script.

@PARAM1 String, filename of validatable file, excluding path, or Git commit title,
                or something else to parse.
@RETURNS String, The unique issue identifier

@THROWS Koha::Exception::Parse, if the unique identifier couldn't be parsed.
=cut

sub getIssueIdentifier {
    my ($self, $fileName) = @_;

    my $allowedIssueIdentifierPrefixes = Koha::AtomicUpdater::getAllowedIssueIdentifierPrefixes();
    foreach my $prefix (keys(%$allowedIssueIdentifierPrefixes)) {
        if ($fileName =~ m/$prefix[-:_ ]*?(\d+(-\d+)?)/i) {
            my $normalizer = $allowedIssueIdentifierPrefixes->{$prefix};
            if ($normalizer eq 'ucfirst') {
                return ucfirst("$prefix$1");
            }
            else {
                return "$prefix$1";
            }
        }
    }
    Koha::Exception::Parse->throw(error => __PACKAGE__."->getIssueIdentifier($fileName):> couldn't parse the unique issue identifier from filename using allowed prefixes '%$allowedIssueIdentifierPrefixes'");
}

1;
