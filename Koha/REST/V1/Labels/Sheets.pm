package Koha::REST::V1::Labels::Sheets;

use Modern::Perl;
use Try::Tiny;
use Scalar::Util qw(blessed);

use Mojo::Base 'Mojolicious::Controller';

use C4::Labels::SheetManager;
use C4::Labels::Sheet;

use Koha::Exception::UnknownObject;

sub list_sheets {
    my ($c, $args, $cb) = @_;

    try {
        my $sheetRows = C4::Labels::SheetManager::getSheetsFromDB();

        if (@$sheetRows > 0) {
            my @sheets;
            foreach my $sheetRow (@$sheetRows) {
                push @sheets, $sheetRow->{sheet};
            }
            return $c->$cb(\@sheets , 200);
        }
        else {
            Koha::Exception::UnknownObject->throw(error => "No sheets found");
        }
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::UnknownObject')) {
            return $c->$cb( {error => $_->error()}, 404 );
        }
        if (blessed($_) && $_->isa('Koha::Exception::DB')) {
            return $c->$cb( {error => $_->error()}, 500 );
        }
        elsif (blessed($_)) {
            $_->rethrow();
        }
        else {
            die $_;
        }
    };
}

sub create_sheet {
    my ($c, $args, $cb) = @_;

    try {
        my $sheetHash = JSON::XS->new()->decode($args->{sheet});
        my $sheet = C4::Labels::Sheet->new($sheetHash);
        C4::Labels::SheetManager::putNewSheetToDB($sheet);
        return $c->$cb($sheet->toJSON(), 201);
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::BadParameter')) {
            return $c->$cb( {error => $_->error()}, 400 );
        }
        if (blessed($_) && $_->isa('Koha::Exception::DB')) {
            return $c->$cb( {error => $_->error()}, 500 );
        }
        elsif (blessed($_)) {
            $_->rethrow();
        }
        else {
            die $_;
        }
    };
}

sub update_sheet {
    my ($c, $args, $cb) = @_;

    try {
        my $sheetHash = JSON::XS->new()->decode($args->{sheet});
        my $sheet = C4::Labels::Sheet->new($sheetHash);
        C4::Labels::SheetManager::putNewVersionToDB($sheet);
        return $c->$cb($sheet->toJSON(), 201);
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::BadParameter')) {
            return $c->$cb( {error => $_->error()}, 400 );
        }
        if (blessed($_) && $_->isa('Koha::Exception::UnknownObject')) {
            return $c->$cb( {error => $_->error()}, 404 );
        }
        if (blessed($_) && $_->isa('Koha::Exception::DB')) {
            return $c->$cb( {error => $_->error()}, 500 );
        }
        elsif (blessed($_)) {
            $_->rethrow();
        }
        else {
            die $_;
        }
    };
}

sub delete_sheet {
    my ($c, $args, $cb) = @_;

    try {
        my $id = $args->{sheet_identifier};
        my $version = $args->{sheet_version};
        C4::Labels::SheetManager::deleteSheet($id, $version);
        return $c->$cb("ok", 204);
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::UnknownObject')) {
            return $c->$cb( {error => $_->error()}, 404 );
        }
        if (blessed($_) && $_->isa('Koha::Exception::DB')) {
            return $c->$cb( {error => $_->error()}, 500 );
        }
        elsif (blessed($_)) {
            $_->rethrow();
        }
        else {
            die $_;
        }
    };
}

sub get_sheet {
    my ($c, $args, $cb) = @_;

    try {
        my $id = $args->{sheet_identifier};
        my $version = $args->{sheet_version};
        my $sheetRow = C4::Labels::SheetManager::getSheetFromDB( $id, undef, $version ); #id name version

        if ($sheetRow) {
            return $c->$cb($sheetRow->{sheet} , 200);
        }
        else {
            Koha::Exception::UnknownObject->throw(error => "No sheet found");
        }
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::UnknownObject')) {
            return $c->$cb( {error => $_->error()}, 404 );
        }
        if (blessed($_) && $_->isa('Koha::Exception::DB')) {
            return $c->$cb( {error => $_->error()}, 500 );
        }
        elsif (blessed($_)) {
            $_->rethrow();
        }
        else {
            die $_;
        }
    };
}

sub list_sheet_versions {
    my ($c, $args, $cb) = @_;

    try {
        my $sheetMetaData = C4::Labels::SheetManager::listSheetVersions();
        my @sheetMetaData = map {C4::Labels::SheetManager::swaggerizeSheetVersion($_)} @$sheetMetaData if ($sheetMetaData && ref($sheetMetaData) eq 'ARRAY');

        if (scalar(@sheetMetaData)) {
            return $c->$cb(\@sheetMetaData, 200);
        }
        else {
            Koha::Exception::UnknownObject->throw(error => "No sheets found");
        }
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::UnknownObject')) {
            return $c->$cb( {error => $_->error()}, 404 );
        }
        if (blessed($_) && $_->isa('Koha::Exception::DB')) {
            return $c->$cb( {error => $_->error()}, 500 );
        }
        elsif (blessed($_)) {
            $_->rethrow();
        }
        else {
            die $_;
        }
    };
}

1;
