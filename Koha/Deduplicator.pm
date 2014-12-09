package Koha::Deduplicator;


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

use C4::Matcher;
use C4::Items qw(GetItemsCount get_itemnumbers_of MoveItemFromBiblio);
use C4::Biblio qw(GetBiblionumberSlice GetMarcBiblio GetBiblioItemByBiblioNumber DelBiblio);
use C4::Serials qw(CountSubscriptionFromBiblionumber);
#use C4::Koha;
use C4::Reserves qw/MergeHolds/;
use C4::Acquisition qw/ModOrder GetOrdersByBiblionumber/;


sub new {
    my ($class, $matcher_id, $limit, $offset, $biblionumber, $verbose) = @_;

    my $self = {};
    ### Validate parameters. ###
    my @initErrors;
    if (not($matcher_id) || $matcher_id !~ /^\d+$/) {
        push @initErrors, "Koha::Deduplicator->new(): Parameter matcher_id $matcher_id must be defined and a number pointing to koha.marc_matchers.matcher_id!";
    }

    if ($limit && $limit !~ /^\d+$/ ) {
        push @initErrors, "$class( $matcher_id, $limit, $offset, $biblionumber ): Parameter limit $limit must be a number!";
    }
    elsif (not($limit)) {
        $limit = 500; #Limit defaults to 500
    }
    $self->{limit} = $limit;

    if ($offset && $offset !~ /^\d+$/ ) {
        push @initErrors, "$class( $matcher_id, $limit, $offset, $biblionumber ): Parameter offset $offset must be a number!";
    }
    elsif (not($offset)) {
        undef $offset; #Offset defaults to undef
    }
    $self->{offset} = $offset;

    if ($biblionumber && $biblionumber !~ /^\d+$/ ) {
        push @initErrors, "$class( $matcher_id, $limit, $offset, $biblionumber ): Parameter biblionumber $biblionumber must be a number!";
    }
    elsif (not($biblionumber)) {
        undef $biblionumber; #Biblionumber defaults to undef
    }
    $self->{biblionumber} = $biblionumber;

    if ($verbose && $verbose !~ /^\d+$/) {
        push @initErrors, "$class( $matcher_id, $limit, $offset, $biblionumber ): Parameter verbose $verbose must be a number or don't define it!";
    }
    elsif ($verbose && $verbose =~ /^\d+$/) {
        $self->{verbose} = $verbose;
    }

    my $matcher = C4::Matcher->fetch($matcher_id);
    if (not($matcher)) {
        push @initErrors, "Koha::Deduplicator->new(): No Matcher with the given matcher_id $matcher_id.";
    }
    $self->{matcher} = $matcher;

    $self->{max_matches} = 100; #Default the max number of matches to return per matched biblionumber to 100
    return (undef, \@initErrors) if scalar(@initErrors) > 0;
    ### Parameters validated ###

    bless $self, $class;
    return ($self, undef);
}

sub deduplicate {
    my $self = shift;
    my $verbose = $self->{verbose};
    my $biblionumbers = C4::Biblio::GetBiblionumberSlice( $self->{limit}, $self->{offset}, $self->{biblionumber} );

    $self->{duplicates} = [];
    foreach my $biblionumber (@$biblionumbers) {
        my $marc = C4::Biblio::GetMarcBiblio($biblionumber);
        my @matches = $self->{matcher}->get_matches( $marc, $self->{max_matches} );

        if (scalar(@matches) > 1) {
            for (my $i=0 ; $i<scalar(@matches) ; $i++) {
                my $match = $matches[$i];
                my $itemsCount = C4::Items::GetItemsCount($match->{record_id});
                $match->{itemsCount} = $itemsCount;
                unless(  _buildSlimBiblio($match->{record_id}, $match, C4::Biblio::GetMarcBiblio($match->{record_id}))  ) {
                    #Sometimes we get an error where the marcxml is not available.
                    splice(@matches, $i, 1);
                    $i--; #Don't advance the iterator after this round or we will skip one record!
                    next();
                }
                if ($match->{record_id} == $biblionumber) {
                    $match->{matchSource} = 'matchSource';
                }
            }
            my $biblio = _buildSlimBiblio($biblionumber, undef, $marc);
            unless ($biblio) { #Sometimes we get an error where the marcxml is not available.
                next();
            }
            $biblio->{matches} = \@matches;

            push @{$self->{duplicates}}, $biblio;
        }
        if ($verbose) {
            print $biblionumber."\n";
        }
    }
    return $self->{duplicates};
}

sub _buildSlimBiblio {
    my ($biblionumber, $biblio, $marc) = @_;

    if ($biblio) {
        $biblio->{biblionumber} = $biblionumber;
    }
    else {
        $biblio = {biblionumber => $biblionumber};
    }
    if (not($marc)) {
        warn "C4::Deduplicator::_buildSlimBiblio(), No MARC::Record for bn:$biblionumber";
        return undef;
    }

    $biblio->{marc} = $marc;

    my $title = $marc->subfield('245','a');
    my $titleField;
    my @titles;
    if ($title) {
        $titleField = '245';
    }
    else {
        $titleField = '240';
        $title = $marc->subfield('240','a');
    }
    my $enumeration = $marc->subfield( $titleField ,'n');
    my $partName = $marc->subfield( $titleField ,'p');
    my $publicationYear = $marc->subfield( '260' ,'c');
    push @titles, $title if $title;
    push @titles, $enumeration if $enumeration;
    push @titles, $partName if $partName;
    push @titles, $publicationYear if $publicationYear;

    my $author = $marc->subfield('100','a');
    $author = $marc->subfield('110','a') unless $author;

    $biblio->{author} = ($author) ? $author : '';
    $biblio->{title} = join(' ', @titles);
    $biblio->{title} = '' unless $biblio->{title};

    return $biblio;
}

=head batchMergeDuplicates

    $deduplicator->batchMergeDuplicates( $duplicates, $mergeTargetFindingAlgorithm );

=cut
sub batchMergeDuplicates {
    my ($self, $duplicates, $mergeTargetFindingAlgorithm) = @_;

    $self->{mergeErrors} = [];
    _findMergeTargets($duplicates, $mergeTargetFindingAlgorithm, $self->{mergeErrors});

    foreach my $duplicate (@$duplicates) {
        foreach my $match (@{$duplicate->{matches}}) {
            if ($match eq $duplicate->{'mergeTarget'}) { #Comparing Perl references, if htey point to the same object.
                next(); #Don't merge itself to oneself.
            }
            merge($match, $duplicate->{'mergeTarget'}, $self->{mergeErrors});
        }
    }
    return $self->{mergeErrors} if scalar @{$self->{mergeErrors}} > 0;
    return undef;
}

sub _findMergeTargets {
    my ($duplicates, $mergeTargetFindingAlgorithm, $errors) = @_;

    if ($mergeTargetFindingAlgorithm eq 'newest') {
        _mergeTargetFindingAlgorithm_newest( $duplicates );
    }
    else {
        warn "Unknown merge target finding algorithm given: '$mergeTargetFindingAlgorithm'";
    }
}

sub _mergeTargetFindingAlgorithm_newest {
    my $duplicates = shift;

    foreach my $duplicate (@$duplicates) {

        my $target_leader; #Run through all matches and find the newest record.
        my $target_leader_f005 = 0;
        foreach my $match (@{$duplicate->{matches}}) {
            my $f005;
            eval {$f005 = $match->{marc}->field('005')->data(); }; #If marc is not defined thia will crash unless we catch the die-signal
            if ($f005 && $f005 > $target_leader_f005) {
                $target_leader = $match;
                $target_leader_f005 = $f005;
            }
        }
        if ($target_leader) {
            $duplicate->{mergeTarget} = $target_leader;
        }
        else {
            warn "Koha::Deduplicator::_mergeTargetFindingAlgorithm_newest($duplicates), Couldn't get the merge target for duplicate bn:".$duplicate->{biblionumber};
        }
    }
}
=head merge
CODE DUPLICATION WARNING!!
Most of this is copypasted from cataloguing/merge.pl

=cut
sub merge {
    my ($match, $mergeTarget, $errors) = @_;

    my $dbh = C4::Context->dbh;
    my $sth;

    my $tobiblio     =  $mergeTarget->{biblionumber};
    my $frombiblio   =  $match->{biblionumber};
    if ($tobiblio == $frombiblio) {
        warn "Koha::Deduplicator::merge($match, $mergeTarget, $errors), source biblio is the same as the destination.";
        return;
    }

    my @notmoveditems;

    # Moving items from the other record to the reference record
    # Also moving orders from the other record to the reference record, only if the order is linked to an item of the other record
    my $itemnumbers = get_itemnumbers_of($frombiblio);
    foreach my $itloop ($itemnumbers->{$frombiblio}) {
        foreach my $itemnumber (@$itloop) {
            my $res = MoveItemFromBiblio($itemnumber, $frombiblio, $tobiblio);
            if (not defined $res) {
                push @notmoveditems, $itemnumber;
            }
        }
    }
    # If some items could not be moved :
    if (scalar(@notmoveditems) > 0) {
        my $itemlist = join(' ',@notmoveditems);
        push @$errors, { code => "CANNOT_MOVE", value => $itemlist };
    }

    # Moving subscriptions from the other record to the reference record
    my $subcount = CountSubscriptionFromBiblionumber($frombiblio);
    if ($subcount > 0) {
        $sth = $dbh->prepare("UPDATE subscription SET biblionumber = ? WHERE biblionumber = ?");
        $sth->execute($tobiblio, $frombiblio);

        $sth = $dbh->prepare("UPDATE subscriptionhistory SET biblionumber = ? WHERE biblionumber = ?");
        $sth->execute($tobiblio, $frombiblio);

    }

    # Moving serials
    $sth = $dbh->prepare("UPDATE serial SET biblionumber = ? WHERE biblionumber = ?");
    $sth->execute($tobiblio, $frombiblio);

    # TODO : Moving reserves

    # Moving orders (orders linked to items of frombiblio have already been moved by MoveItemFromBiblio)
    my @allorders = GetOrdersByBiblionumber($frombiblio);
    my @tobiblioitem = GetBiblioItemByBiblioNumber ($tobiblio);
    my $tobiblioitem_biblioitemnumber = $tobiblioitem [0]-> {biblioitemnumber };
    foreach my $myorder (@allorders) {
        $myorder->{'biblionumber'} = $tobiblio;
        ModOrder ($myorder);
    # TODO : add error control (in ModOrder?)
    }

    # Deleting the other record
    if (scalar(@$errors) == 0) {
        # Move holds
        MergeHolds($dbh,$tobiblio,$frombiblio);
        my $error = DelBiblio($frombiblio);
        push @$errors, $error if ($error);
    }
}

sub printDuplicatesAsText {
    my ($self) = @_;

    foreach my $duplicate (@{$self->{duplicates}}) {
        print 'Match source: '.$duplicate->{biblionumber}.' - '.$duplicate->{title}.' '.$duplicate->{author}."\n";
        foreach my $match (@{$duplicate->{matches}}) {
            print $match->{record_id}.' - '.$match->{score}.' '.$match->{itemsCount}.'  '.$match->{title}.' '.$match->{author}."\n";
        }
        print "\n\n";
    }
}

sub printMergesAsText {
    my ($self) = @_;
    foreach my $error (@{$self->{mergeErrors}}) {
        print $error;
    }
}
1;