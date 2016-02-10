package Koha::REST::V1::Reserves;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Dates;
use C4::Reserves;

sub edit_reserve {
    my ($c, $args, $cb) = @_;

    my $reserve_id = $args->{reserve_id};
    my $reserve = C4::Reserves::GetReserve($reserve_id);

    unless ($reserve) {
        return $c->$cb({error => "Reserve not found"}, 404);
    }

    my $body = $c->req->json;

    my $branchcode = $body->{branchcode};
    my $priority = $body->{priority};
    my $suspend_until = $body->{suspend_until};

    if ($suspend_until) {
        $suspend_until = C4::Dates->new($suspend_until, 'iso')->output;
    }

    my $params = {
        reserve_id => $reserve_id,
        branchcode => $branchcode,
        rank => $priority,
        suspend_until => $suspend_until,
    };
    C4::Reserves::ModReserve($params);
    $reserve = C4::Reserves::GetReserve($reserve_id);

    return $c->$cb($reserve, 200);
}

sub delete_reserve {
    my ($c, $args, $cb) = @_;

    my $reserve_id = $args->{reserve_id};
    my $reserve = C4::Reserves::GetReserve($reserve_id);

    unless ($reserve) {
        return $c->$cb({error => "Reserve not found"}, 404);
    }

    C4::Reserves::CancelReserve({ reserve_id => $reserve_id });

    return $c->$cb(undef, 204);
}

1;
