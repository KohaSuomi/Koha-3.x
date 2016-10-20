package t::lib::Mojo;

use Modern::Perl;

use Mojo::Parameters;

=head2 getWithFormData

    t::lib::Mojo::getWithFormData(Mojo::Test, $path, $parametersHash);

#Make a custom GET request with formData parameters :) Mojo-fu!

=cut

sub getWithFormData {
    my ($driver, $path, $formData) = @_;

    my $ua = $driver->ua;
    my $tx = $ua->build_tx(GET => $path => {Accept => '*/*'});
    $tx->req->body( Mojo::Parameters->new(%$formData)->to_string);
    $tx->req->headers->remove('Content-Type');
    $tx->req->headers->add('Content-Type' => 'application/x-www-form-urlencoded');
    $tx = $ua->start($tx);
    return $tx;
}

1;
