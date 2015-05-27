package SImpls::Accountlines;

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
use Test::More;

use Koha::Database;


sub deleteAllFines {
    my $schema = Koha::Database->new()->schema();
    $schema->resultset('Accountline')->search({})->delete_all();
}

sub checkAccountlines {
    my $C = shift;
    my $S = $C->{stash}->{scenario};
    my $F = $C->{stash}->{feature};

    my $checks = $C->data(); #Get the checks, which might not have manifested itselves to the message_queue_items
    ok(($checks && scalar(@$checks) > 0), "You must give checks as the data");

    #See which checks are supposed to be in the accountlines-table, and which are just to clarify intent.
    my @checksToDo;
    foreach my $check (@$checks) {
        my $status = $check->{fine};
        push @checksToDo, $check if ($status ne 'none');
    }

    ##Make sure that there are no trailing Accountlines.
    my $schema = Koha::Database->new()->schema();
    my $allFinesCount = $schema->resultset('Accountline')->search({})->count();
    is($allFinesCount, scalar(@checksToDo), "We should have ".scalar(@checksToDo)." checks for $allFinesCount fines, with no trailing fines.");

    my $dbh = C4::Context->dbh();
    my $check_statement = $dbh->prepare(
        "SELECT 1 FROM accountlines a ".
        "LEFT JOIN borrowers b ON a.borrowernumber = b.borrowernumber ".
        "WHERE b.cardnumber = ? AND a.amountoutstanding = ? ".
    "");

    ##Check that there is a matching Accountline for each given test.
    foreach my $check (@checksToDo) {
        my @params;
        push @params, $check->{cardnumber};
        push @params, $check->{fine};
        $check_statement->execute( @params );
        my $ok = $check_statement->fetchrow();
        last unless ok(($ok && $ok == 1), "Check: For params @params");
    }
}

1;
