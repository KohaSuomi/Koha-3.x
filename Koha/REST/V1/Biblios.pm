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

    #Check if there are component part records to delete
    my $record = C4::Biblio::GetMarcBiblio($biblio->biblionumber);
    my @removalErrors;
    foreach my $componentPartBiblionumber (  @{C4::Biblio::getComponentBiblionumbers( $record )}  ) {
        my $error = C4::Biblio::DelBiblio($componentPartBiblionumber);
        my $html = "<a href='/cgi-bin/koha/catalogue/detail.pl?biblionumber=$componentPartBiblionumber'>$componentPartBiblionumber</a>";
        push(@removalErrors, $html.' : '.$error) if $error;
    }
    if (@removalErrors) {
        warn "ERROR when DELETING COMPONENT PART BIBLIOS: \n" . join("\n",@removalErrors);
        return $c->$cb({error => "Deleting component parts failed.\n@removalErrors\n"}, 400);
    }
    #I think we got them all!

    my $errors = C4::Biblio::DelBiblio( $args->{biblionumber} );
    if ($errors) {
        return $c->$cb({error => $errors}, 400);
    }

    return $c->$cb('', 204);
}

1;
