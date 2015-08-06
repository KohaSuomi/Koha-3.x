package Koha::REST::V1::Biblios;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use Koha::Database;

sub delete_biblio {
    my ($c, $args, $cb) = @_;

    my $schema = Koha::Database->new->schema;

    my $biblio = $schema->resultset('Biblio')->find({biblionumber => $args->{biblionumber}});
    unless ($biblio) {
        return $c->$cb({error => "Biblio not found"}, 404);
    }

    my $itemCount = $schema->resultset('Item')->search({biblionumber => $args->{biblionumber}})->count();
    if ($itemCount) {
        return $c->$cb({error => "Biblio has Items attached. Delete them first."}, 400);
    }

    $biblio->delete();
    return $c->$cb('', 204);
}

1;
