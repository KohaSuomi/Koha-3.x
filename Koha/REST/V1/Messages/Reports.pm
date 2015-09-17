package Koha::REST::V1::Messages::Reports;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Letters;
use Data::Dumper;



=head2 list_messages($c, $args, $cb)

Lists all messages from message_queue.

=cut
sub create_labyrintti_report {
    my ($c, $args, $cb) = @_;

    my $message = C4::Letters::GetMessage($args->{'messagenumber'});

    return $c->$cb({ error => "No messages found." }, 404) if not $message;

    # delivery was failed. edit status to failed and add delivery note
    if ($args->{'status'} eq "ERROR") {
        C4::Letters::UpdateQueuedMessage({
                            message_id      => $message->{message_id},
                            status          => 'failed',
                            delivery_note   => $args->{message},
                    });
        return $c->$cb('', 201);
    }

    return $c->$cb('', 204);
}

1;
