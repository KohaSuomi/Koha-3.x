package Koha::REST::V1::Borrowers::Issues;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Circulation;

sub list_borrower_issues {
    my ($c, $args, $cb) = @_;

    my $issues = C4::Circulation::GetIssues({
        borrowernumber => $args->{borrowernumber}
    });

    $c->$cb($issues, 200);
}

sub get_borrower_issue {
    my ($c, $args, $cb) = @_;

    my $borrowernumber = $args->{borrowernumber};
    my $itemnumber = $args->{itemnumber};

    my ($issue) = @{ C4::Circulation::GetIssues({ itemnumber => $itemnumber }) };
    if (!$issue or $borrowernumber != $issue->{borrowernumber}) {
        return $c->$cb({
            error => "Item $itemnumber is not issued to borrower $borrowernumber"
        }, 404);
    }

    return $c->$cb($issue, 200);
}

sub renew_borrower_issue {
    my ($c, $args, $cb) = @_;

    my $borrowernumber = $args->{borrowernumber};
    my $itemnumber = $args->{itemnumber};

    my ($issue) = @{ C4::Circulation::GetIssues({ itemnumber => $itemnumber }) };
    if (!$issue or $borrowernumber != $issue->{borrowernumber}) {
        return $c->$cb({
            error => "Item $itemnumber is not issued to borrower $borrowernumber"
        }, 404);
    }

    my ($can_renew, $error) = C4::Circulation::CanBookBeRenewed($borrowernumber,
        $itemnumber);
    if (!$can_renew) {
        return $c->$cb({error => "Renewal not authorized ($error)"}, 403);
    }

    AddRenewal($borrowernumber, $itemnumber, $issue->{branchcode});
    ($issue) = @{ C4::Circulation::GetIssues({ itemnumber => $itemnumber }) };

    return $c->$cb($issue, 200);
}

1;
