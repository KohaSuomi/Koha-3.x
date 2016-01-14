package Koha::BiblioDataElements;

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
use Carp;
use DateTime;
use DateTime::Format::HTTP;
use Scalar::Util qw(blessed);
use MARC::Record;
use MARC::File::XML;

use Koha::Database;
use Koha::BiblioDataElement;

use Koha::Exception::FeatureUnavailable;

use base qw(Koha::Objects);

sub type {
    return 'BiblioDataElement';
}

sub object_class {
    return 'Koha::BiblioDataElement';
}

=head UpdateBiblioDataElements

    Koha::BiblioDataElements::UpdateBiblioDataElements([$limit]);

Finds all biblioitems that have changed since the last time biblio_data_elements has been updated.
Extracts biblio_data_elements from those MARCXMLs'.
@PARAM1, Boolean, should we UPDATE all biblioitems BiblioDataElements or simply increment changes?
@PARAM2, Int, the SQL LIMIT-clause, or undef.
@PARAM3, Int, verbosity level. See update_biblio_data_elements.pl-cronjob
=cut

sub UpdateBiblioDataElements {
    my ($forceRebuild, $limit, $verbose) = @_;

    $verbose = 0 unless $verbose; #Prevent undefined comparison errors

    my $biblioitems = _getBiblioitemsNeedingUpdate($forceRebuild, $limit, $verbose);

    if ($biblioitems && ref $biblioitems eq 'ARRAY') {
        print "Found '".scalar(@$biblioitems)."' biblioitems-records to update.\n" if $verbose > 0;
        foreach my $biblioitem (@$biblioitems) {
            UpdateBiblioDataElement($biblioitem);
        }
    }
    elsif ($verbose > 0) {
        print "Nothing to UPDATE\n";
    }
}

=head UpdateBiblioDataElement

    Koha::BiblioDataElements::UpdateBiblioDataElement($biblioitem, $verbose);

Takes biblioitems and MARCXML and picks the needed data_elements to the koha.biblio_data_elements -table.
@PARAM1, Koha::Biblioitem or a HASH of koha.biblioitems-row.
@PARAM2, Int, verbosity level. See update_biblio_data_elements.pl-cronjob

=cut

sub UpdateBiblioDataElement {
    my ($biblioitem, $verbose) = @_;
    $verbose = 0 unless $verbose; #Prevent undef errors

    #Get the bibliodataelement from input which can be a Koha::Object or a HASH from DBI
    #or create a new one if the biblioitem is new.
    my $bde; #BiblioDataElement-object
    my $marcxml;
    my $deleted;
    my $itemtype;
    my $biblioitemnumber;
    if (blessed $biblioitem && $biblioitem->isa('Koha::Object')) {
        my @bde = Koha::BiblioDataElements->search({biblioitemnumber => $biblioitem->biblioitemnumber()});
        $bde = $bde[0];
        $marcxml = $biblioitem->marcxml();
        $deleted = $biblioitem->deleted();
        $itemtype = $biblioitem->itemtype();
        $biblioitemnumber = $biblioitem->biblioitemnumber();
    }
    else {
        my @bde = Koha::BiblioDataElements->search({biblioitemnumber => $biblioitem->{biblioitemnumber}});
        $bde = $bde[0];
        $marcxml = $biblioitem->{marcxml};
        $deleted = $biblioitem->{deleted};
        $itemtype = $biblioitem->{itemtype};
        $biblioitemnumber = $biblioitem->{biblioitemnumber};
    }
    $bde = Koha::BiblioDataElement->new({biblioitemnumber => $biblioitemnumber}) unless $bde;

    #Make a MARC::Record out of the XML.
    my $record = eval { MARC::Record::new_from_xml( $marcxml, "utf8", C4::Context->preference('marcflavour') ) };
    print $@;

    #Start creating data_elements.
    $bde->isFiction($record);
    $bde->isMusicalRecording($record);
    $bde->setDeleted($deleted);
    $bde->setItemtype($itemtype);
    $bde->isSerial($itemtype);
    $bde->setLanguages($record);
    $bde->store();
}

=head GetLatestDataElementUpdateTime

    Koha::BiblioDataElements::GetLatestDataElementUpdateTime($forceRebuild, $verbose);

Finds the last time koha.biblio_data_elements has been UPDATED.
If the table is empty, returns undef
@PARAM1, Int, verbosity level. See update_biblio_data_elements.pl-cronjob
@RETURNS DateTime or undef, last modification time
=cut
sub GetLatestDataElementUpdateTime {
    my ($verbose) = @_;
    my $dbh = C4::Context->dbh();
    my $sthLastModTime = $dbh->prepare("SELECT MAX(last_mod_time) as last_mod_time FROM biblio_data_elements;");
    $sthLastModTime->execute( );
    my $rv = $sthLastModTime->fetchrow_hashref();
    my $lastModTime = ($rv && $rv->{last_mod_time}) ? $rv->{last_mod_time} : undef;
    print "Latest koha.biblio_data_elements updating time '".($lastModTime || '')."'\n" if $verbose;
    return $lastModTime unless $lastModTime;
    $lastModTime = '1900-01-01 01:01:01' if $lastModTime =~ /^0000-00-00[T ]/;
    my $dt = DateTime::Format::HTTP->parse_datetime($lastModTime);
    $dt->set_time_zone( C4::Context->tz() );
    return $dt;
}

=head _getBiblioitemsNeedingUpdate
Finds the biblioitems whose timestamp (time last modified) is bigger than the biggest last_mod_time in koha.biblio_data_elements
=cut

sub _getBiblioitemsNeedingUpdate {
    my ($forceRebuild, $limit, $verbose) = @_;

    if ($limit) {
        $limit = " LIMIT $limit ";
        $limit =~ s/;//g; #Evade SQL injection :)
    }
    else {
        $limit = '';
    }

    print '#'.DateTime->now(time_zone => C4::Context->tz())->iso8601().'# Fetching biblioitems  #'."\n" if $verbose > 0;

    my $lastModTime;
    if ($forceRebuild) {
        $lastModTime = '1900-01-01 01:01:01';
    }
    else {
        $lastModTime = GetLatestDataElementUpdateTime($verbose)->iso8601() || '1900-01-01 01:01:01';
    }

    my $dbh = C4::Context->dbh();
    my $sthBiblioitems = $dbh->prepare("
            (SELECT biblioitemnumber, itemtype, marcxml, 0 as deleted FROM biblioitems
             WHERE timestamp >= ? $limit
            ) UNION (
             SELECT biblioitemnumber, itemtype, marcxml, 1 as deleted FROM deletedbiblioitems
             WHERE timestamp >= ? $limit
            )
    ");
    $sthBiblioitems->execute( $lastModTime, $lastModTime );
    my $biblioitems = $sthBiblioitems->fetchall_arrayref({});

    print '#'.DateTime->now(time_zone => C4::Context->tz())->iso8601().'# Biblioitems fetched #'."\n" if $verbose > 0;

    return $biblioitems;
}

=head verifyFeatureIsInUse

    my $ok = Koha::BiblioDataElements::verifyFeatureIsInUse();

@RETURNS Flag, 1 if this feature is properly configured
@THROWS Koha::Exception::FeatureUnavailable if this feature is not in use.
=cut

sub verifyFeatureIsInUse {
    my $now = DateTime->now(time_zone => C4::Context->tz());
    my $lastUpdateTime = Koha::BiblioDataElements::GetLatestDataElementUpdateTime() || '1900-01-01 01:01:01';
    my $lastUpdateTimeDt = DateTime::Format::HTTP->parse_datetime($lastUpdateTime);
    my $difference = $now->subtract_datetime( $lastUpdateTimeDt );
    if ($difference->in_units( 'days' ) > 2) {
        my @cc = caller(0);
        Koha::Exception::FeatureUnavailable->throw(error => $cc[3]."():> koha.biblio_data_elements-table is stale. You must configure cronjob 'update_biblio_data_elements.pl' to run daily.");
    }
    return 1;
}

=head markForReindex

    Koha::BiblioDataElements::markForReindex();

Marks all BiblioDataElements to be updated during the next indexing.

=cut

sub markForReindex {
    my $dbh = C4::Context->dbh();
    $dbh->do("UPDATE biblio_data_elements SET last_mod_time = '1900-01-01 01:01:01'");
}

1;
