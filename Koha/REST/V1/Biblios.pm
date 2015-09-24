package Koha::REST::V1::Biblios;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Database;
use C4::Biblio;

sub delete_biblio {
    my ($c, $args, $cb) = @_;

    my $schema = Koha::Database->new->schema;

    my $biblio = $schema->resultset('Biblio')->find({biblionumber => $args->{biblionumber}});
    unless ($biblio) {
        return $c->$cb({error => "Biblio not found"}, 404);
    }

    my $errors = C4::Biblio::DelBiblio( $args->{biblionumber} );
    if ($errors) {
        return $c->$cb({error => $errors}, 400);
    }

    return $c->$cb('', 204);
}

1;
