package C4::Members::Statistics;

# Copyright 2012 BibLibre
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

=head1 NAME

C4::Members::Statistics - Get statistics for patron checkouts

=cut

use Modern::Perl;

use C4::Context;

our ( @ISA, @EXPORT, @EXPORT_OK, $debug );

BEGIN {
    $debug = $ENV{DEBUG} || 0;
    require Exporter;
    @ISA = qw(Exporter);

    push @EXPORT, qw(
        &GetTotalIssuesTodayByBorrower
        &GetTotalIssuesReturnedTodayByBorrower
        &GetPrecedentStateByBorrower
    );
}


our $fields = get_fields();
our $tmpSelectAlias = 'tmp';

sub get_fields {
    my $r = C4::Context->preference('StatisticsFields') || 'location|itype|ccode';
    unless ( $r =~ m/^(\w|\d|\||-)+$/) {
        warn "Members/Statistics : Bad value for syspref StatisticsFields" if $debug;
        $r = 'location|itype|ccode';
    }
    return $r;
}

=head2 construct_query
  Build a sql query from a subquery
  Adds statistics fields to the select and the group by clause
=cut
sub construct_query {
    my $count    = shift;
    my $subquery = shift;

    my @select_fields;
    #Some DB engines and/or MySQL variants cannot cope with return-keyword, thus it needs to be prefixed.
    if ($subquery =~ /$tmpSelectAlias$/) {
        @select_fields = map {"$tmpSelectAlias.$_"} split('\|', $fields);
    }
    else {
        @select_fields = map {($_ =~ /return/) ? "i.$_" : $_} split('\|', $fields);
    }

    my $query = "SELECT COUNT(*) as count_$count,";
    $query .= join ',', @select_fields;

    $query .= " " . $subquery;

    $query .= " GROUP BY ".join(',', @select_fields);

    return $query;

}

=head2 GetTotalIssuesTodayByBorrower
  Return total issues for a borrower at this current day
=cut
sub GetTotalIssuesTodayByBorrower {
    my ($borrowernumber) = @_;
    my $dbh   = C4::Context->dbh;

    my $query = construct_query "total_issues_today",
        "FROM (
            SELECT it.*, i.return FROM issues i, items it WHERE i.itemnumber = it.itemnumber AND i.borrowernumber = ? AND DATE(i.issuedate) = CAST(now() AS date)
            UNION
            SELECT it.*, oi.return FROM old_issues oi, items it WHERE oi.itemnumber = it.itemnumber AND oi.borrowernumber = ? AND DATE(oi.issuedate) = CAST(now() AS date)
        ) $tmpSelectAlias";     # alias is required by MySQL

    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber, $borrowernumber);
    return $sth->fetchall_arrayref( {} );
}

=head2 GetTotalIssuesReturnedTodayByBorrower
  Return total issues returned by a borrower at this current day
=cut
sub GetTotalIssuesReturnedTodayByBorrower {
    my ($borrowernumber) = @_;
    my $dbh   = C4::Context->dbh;

    my $query = construct_query "total_issues_returned_today", "FROM old_issues i, items it WHERE i.itemnumber = it.itemnumber AND i.borrowernumber = ? AND DATE(i.returndate) = CAST(now() AS date) ";

    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber);
    return $sth->fetchall_arrayref( {} );
}

=head2 GetPrecedentStateByBorrower
  Return the precedent state (before today) for a borrower of his checkins and checkouts
=cut
sub GetPrecedentStateByBorrower {
    my ($borrowernumber) = @_;
    my $dbh   = C4::Context->dbh;

    my $query = construct_query "precedent_state",
        "FROM (
            SELECT it.*, i.return FROM issues i, items it WHERE i.borrowernumber = ? AND i.itemnumber = it.itemnumber AND DATE(i.issuedate) < CAST(now() AS date)
            UNION
            SELECT it.*, oi.return FROM old_issues oi, items it WHERE oi.borrowernumber = ? AND oi.itemnumber = it.itemnumber AND DATE(oi.issuedate) < CAST(now() AS date) AND DATE(oi.returndate) = CAST(now() AS date)
        ) $tmpSelectAlias";     # alias is required by MySQL

    my $sth = $dbh->prepare($query);
    $sth->execute($borrowernumber, $borrowernumber);
    return $sth->fetchall_arrayref( {});
}

1;
