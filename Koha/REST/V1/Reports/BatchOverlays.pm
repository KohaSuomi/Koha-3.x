package Koha::REST::V1::Reports::BatchOverlays;

use Modern::Perl;
use Data::Dumper;
use Scalar::Util qw(blessed);
use Try::Tiny;
use DateTime::Format::RFC3339;
use DateTime::Format::MySQL;

use Mojo::Base 'Mojolicious::Controller';

use C4::BatchOverlay::ReportManager;

use Koha::Exception::UnknownObject;


sub list_report_containers {
    my ($c, $args, $cb) = @_;

    my $containers = C4::BatchOverlay::ReportManager->listReports();

    if (scalar(@$containers)) {
        return $c->$cb( _swaggerizeReportContainers($containers), 200 );
    }
    else {
        return $c->$cb({error => "No containers found"}, 404);
    }
}

sub list_reports {
    my ($c, $args, $cb) = @_;

    my $reports = C4::BatchOverlay::ReportManager->getReports($args->{reportContainerId}, $args->{showAllExceptions});

    if (scalar(@$reports)) {
        return $c->$cb( _swaggerizeReports($reports), 200 );
    }
    else {
        return $c->$cb({error => "No reports found"}, 404);
    }
}

sub _swaggerizeReportContainer {
    my ($container) = @_;
    $container->{id}             = 0+$container->{id},
    $container->{borrowernumber} = 0+$container->{borrowernumber},
    $container->{reportsCount}   = 0+$container->{reportsCount},
    $container->{errorsCount}    = 0+$container->{errorsCount},
    $container->{timestamp}      = DateTime::Format::RFC3339->format_datetime( DateTime::Format::MySQL->parse_datetime($container->{timestamp}) ),
    return $container;
}
sub _swaggerizeReportContainers {
    my ($containers) = @_;
    for (my $i=0 ; $i<scalar(@$containers) ; $i++) {
        $containers->[$i] = _swaggerizeReportContainer($containers->[$i]);
    }
    return $containers;
}
sub _swaggerizeReport {
    my ($r) = @_;

    my $swag = {
        id =>                int($r->getId()),
        reportContainerId => int($r->getReportContainerId()),
        biblionumber =>      int($r->getBiblionumber() || 0) || undef,
        timestamp =>         DateTime::Format::RFC3339->new()->format_datetime( $r->getTimestamp() ),
        operation =>         $r->getOperation(),
        ruleName =>          $r->getRuleName(),
        diff =>              $r->serializeDiff(),
        headers =>           [],
    };
    my $headers = $r->getHeaders();
    foreach my $h (@$headers) {
        my $swgHd = {
            id =>                   int($h->getId()),
            batchOverlayReportId => int($h->getBatchOverlayReportId()),
            biblionumber =>         (defined($h->getBiblionumber())) ? int($h->getBiblionumber()) : undef,
            breedingid =>           (defined($h->getBreedingid())) ? int($h->getBreedingid()) : undef,
            title =>                $h->getTitle() || '',
            stdid =>                $h->getStdid() || '',
        };
        push(@{$swag->{headers}}, $swgHd);
    }
    return $swag;
}
sub _swaggerizeReports {
    my ($reports) = @_;
    for (my $i=0 ; $i<scalar(@$reports) ; $i++) {
        $reports->[$i] = _swaggerizeReport($reports->[$i]);
    }
    return $reports;
}

1;
