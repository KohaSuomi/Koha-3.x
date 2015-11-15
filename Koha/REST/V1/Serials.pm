package Koha::REST::V1::Serials;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Serials;

sub get_serial_items {
    my ($c, $args, $cb) = @_;

    eval {
        my $serialItems = C4::Serials::GetSerialItems($args);

        return $c->$cb({ serialItems => $serialItems}, 200);
    };
    if ($@) {
        return $c->$cb( {description => $@, type => "Database"}, 500 );
    }
}

sub get_collection {
    my ($c, $args, $cb) = @_;

    eval {
        my $collectionMap = C4::Serials::GetCollectionMap($args);

        return $c->$cb({ collectionMap => $collectionMap}, 200);
    };
    if ($@) {
        return $c->$cb( {description => $@, type => "Database"}, 500 );
    }
}

1;
