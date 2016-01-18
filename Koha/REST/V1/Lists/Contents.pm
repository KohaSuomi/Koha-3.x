package Koha::REST::V1::Lists::Contents;

use Modern::Perl;
use Try::Tiny;
use Scalar::Util qw(blessed);

use Mojo::Base 'Mojolicious::Controller';

use C4::VirtualShelves;

use Koha::Exception::UnknownObject;
use Koha::Exception::BadParameter;

sub add_to_list {
    my ($c, $args, $cb) = @_;

    try {
        my $listContent = $args->{listContent};
        C4::VirtualShelves::addItemToList($listContent->{biblionumber}, $listContent->{listname}, $listContent->{borrowernumber}, $listContent->{itemnumber});
        return $c->$cb($args, 200);
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::UnknownObject')) {
            return $c->$cb( {error => $_->error()}, 404 );
        }
        if (blessed($_) && $_->isa('Koha::Exception::BadParameter')) {
            return $c->$cb( {error => $_->error()}, 400 );
        }
        elsif (blessed($_)) {
            $_->rethrow();
        }
        else {
            die $_;
        }
    };
}
sub delete_contents {
    my ($c, $args, $cb) = @_;

    try {
        my $listContent = $args->{listContent};
        C4::VirtualShelves::removeLabelPrintingListItems($listContent->{borrowernumber});
        return $c->$cb($args, 200);
    } catch {
        if (blessed($_)) {
            $_->rethrow();
        }
        else {
            die $_;
        }
    };
}

1;