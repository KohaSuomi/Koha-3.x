package Koha::REST::V1::Messages;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Letters;
use Data::Dumper;
use C4::Log;


=head2 list_messages($c, $args, $cb)

Lists all messages from message_queue.

=cut
sub list_messages {
    my ($c, $args, $cb) = @_;

    my $messages = C4::Letters::swaggerize( C4::Letters::GetQueuedMessages() );

    if (@$messages > 0) {
        return $c->$cb($messages , 200);
    }
    $c->$cb({ error => "No messages found." }, 404);
}



=head2 create_message($c, $args, $cb)

Creates a new message into message queue.

=cut
sub create_message {
    my ($c, $args, $cb) = @_;

    # Content is required. Check for missing content.
    if (exists $args->{body}->{content}) {
        my $content = $args->{body}->{content};
        $content =~ s/\s+//g if(defined $content);
        if ( not $content ) {
            return $c->$cb({ error => "Property cannot be empty in: /body/content" }, 400);
        }
    } else {
        return $c->$cb({ error => "Missing property: /body/content" }, 400);
    }

    if (exists $args->{body}->{borrowernumber}) {
        my $content = $args->{body}->{borrowernumber};
        $content =~ s/\s+//g if(defined $content);
        if ( not $content ) {
            return $c->$cb({ error => "Property cannot be empty in: /body/borrowernumber" }, 400);
        }
    } else {
        return $c->$cb({ error => "Missing property: /body/borrowernumber" }, 400);
    }


    # message_transport_type is required. Check for missing parameter.
    my $transport_type = $args->{body}->{message_transport_type};
    $transport_type =~ s/\s+//g if(defined $transport_type);
    if ( not $transport_type ) {
        return $c->$cb({ error => "Missing property: /body/message_transport_type" }, 400);
    }

    # message_transport_type also must be one of the predefined values
    my $transport_types = C4::Letters::GetMessageTransportTypes();
    if ( !grep( /^$transport_type$/, @$transport_types ) ) {
        return $c->$cb({ error => "Invalid value '".$transport_type."' in: /body/message_transport_type. Valid values are ". join(', ', @$transport_types) }, 400);
    }

    # Make some changes in names of parameters due to inconsistent naming in C4::Letters

    # Enqueue the letter
    my $message = C4::Letters::EnqueueLetter(_convert_to_enqueue({ message => $args->{'body'} }));

    # Check if the message was enqueued
    if ($message){
        # Get the newly created message and return it
        $message = C4::Letters::GetMessage( $message );

        $message = C4::Letters::swaggerize($message);

        &logaction(
        "NOTICES",
        "CREATE",
        $message->{message_id},
        ""
        );

        return $c->$cb($message, 201);
    }
    $c->$cb({ error => "Message could not be created." }, 404)
}



=head2 update_message($c, $args, $cb)

Updates the message in message_queue.

=cut
sub update_message {
    my ($c, $args, $cb) = @_;

    # Content is required. Check for missing content.
    if (exists $args->{body}->{content}) {
        my $content = $args->{body}->{content};
        $content =~ s/\s+//g if(defined $content);
        if ( $content eq '' ) {
            return $c->$cb({ error => "Property cannot be empty in: /body/content" }, 400);
        }
    }

    if (exists $args->{body}->{message_transport_type}) {
        my $transport_type = $args->{body}->{message_transport_type};
        # message_transport_type also must be one of the predefined values
        my $transport_types = C4::Letters::GetMessageTransportTypes();
        if ( !grep( /^$transport_type$/, @$transport_types ) ) {
            return $c->$cb({ error => "Invalid value '".$transport_type
                            ."' in: /body/message_transport_type. Valid values are "
                            . join(', ', @$transport_types) }, 400);
        }
    }

    # create update hash
    my $update = $args->{'body'};
    $update->{'message_id'} = $args->{'messagenumber'};

    my $message = C4::Letters::UpdateQueuedMessage( $update );
    return $c->$cb({ error => "Message could not be found." }, 404) if not $message;

    $message = C4::Letters::GetMessage($args->{'messagenumber'});

    if ($message){
        $message = C4::Letters::swaggerize($message);

        &logaction(
        "NOTICES",
        "UPDATE",
        $message->{message_id},
        ""
        );

        return $c->$cb($message, 200);
    }
    $c->$cb({ error => "Message could not be updated." }, 404);
}



=head2 delete_message($c, $args, $cb)

Delete the message from message_queue.

=cut
sub delete_message {
    my ($c, $args, $cb) = @_;

    my $message = C4::Letters::DequeueLetter({ message_id => $args->{'messagenumber'} });

    if ($message){

        &logaction(
        "NOTICES",
        "DELETE",
        $args->{'messagenumber'},
        ""
        );

        return $c->$cb('', 204);
    }

    $c->$cb({ error => "Message could not be found." }, 404)
}



=head2 get_message($c, $args, $cb)

Returns a message from message_queue.

=cut
sub get_message {
    my ($c, $args, $cb) = @_;

    my $message = C4::Letters::GetMessage($args->{'messagenumber'});

    if ($message) {
        my $message = C4::Letters::swaggerize($message);

        return $c->$cb($message, 200);
    }

    return $c->$cb({ error => "Could not find the message" }, 404);
}



=head2 create_resend($c, $args, $cb)

Attempts to resend a message.

=cut
sub create_resend {
    my ($c, $args, $cb) = @_;


    my $message = C4::Letters::GetMessage($args->{'messagenumber'});

    if ($message) {
        if (C4::Letters::ResendMessage($args->{'messagenumber'})) {

            &logaction(
            "NOTICES",
            "RESEND",
            $message->{message_id},
            ""
            );

            return $c->$cb('', 204);
        }
    }

    return $c->$cb({ error => "Could not find the message" }, 404);
}



=head2 _convert_to_enqueue({ message => $message })

Due to inconsistent naming in C4::Letters::EnqueueLetter, we use the
database format and convert it in this function into the format that
EnqueueLetter supports.

=cut
sub _convert_to_enqueue {
    my $params = shift;

    return unless exists $params->{'message'} or not defined $params->{'message'};

    # Convert the returned message into C4::Letters::EnqueueLetter format
    return {
        borrowernumber => int($params->{'message'}->{'borrowernumber'}),
        letter => {
            title => $params->{'message'}->{'subject'} || '',
            content => $params->{'message'}->{'content'} || '',
            code => $params->{'message'}->{'letter_code'} || '',
            'content-type' => $params->{'message'}->{'content_type'} || '',
            metadata => $params->{'message'}->{'metadata'} || '',
        },
        message_transport_type => $params->{'message'}->{'message_transport_type'} || '',
        to_address => $params->{'message'}->{'to_address'} || '',
        from_address => $params->{'message'}->{'from_address'} || '',
        delivery_note => $params->{'message'}->{'delivery_note'} || ''
    };
}

1;
