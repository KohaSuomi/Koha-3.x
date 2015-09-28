package Koha::REST::V1;

use Modern::Perl;
use Mojo::Base 'Mojolicious';

sub startup {
    my $self = shift;

    my $route = $self->routes->under->to(
        cb => sub {
            my $c = shift;
            my $user = $c->param('user');
            # Do the authentication stuff here...
            $c->stash('user', $user);
            return 1;
        }
    );

    $self->plugin(Swagger2 => {
        route => $route,
        url => $self->home->rel_file("api/v1/swagger.json"),
    });
}

1;
