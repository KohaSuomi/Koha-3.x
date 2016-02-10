package Koha::Borrower;

# Copyright ByWater Solutions 2014
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Carp;

use Koha::Database;

use base qw(Koha::Object);

=head1 NAME

Koha::Borrower - Koha Borrower Object class

=head1 API

=head2 Class Methods

=cut

=head3 type

=cut

sub type {
    return 'Borrower';
}

=head isSuperuser

    $borrower->isSuperuser(1); #Set this borrower to be a superuser
    if ($borrower->isSuperuser()) {
        #All your base are belong to us
    }

Should be used from the authentication modules to mark this $borrower-object to
have unlimited access to all Koha-features.
This $borrower-object is the Koha DB user.
@PARAM1 Integer, 1 means this borrower is the super/DB user.
                "0" disables the previously set superuserness.
=cut

sub isSuperuser {
    my ($self, $Iam) = @_;

    if (defined $Iam && $Iam == 1) {
        $self->{superuser} = 1;
    }
    elsif (defined $Iam && $Iam eq "0") { #Dealing with zero is special in Perl
        $self->{superuser} = undef;
    }
    return (exists($self->{superuser}) && $self->{superuser}) ? 1 : undef;
}

=head getApiKeys

    my @apiKeys = $borrower->getApiKeys( $activeOnly );

=cut

sub getApiKeys {
    my ($self, $activeOnly) = @_;

    my @dbix_objects = $self->_result()->api_keys({active => 1});
    for (my $i=0 ; $i<scalar(@dbix_objects) ; $i++) {
        $dbix_objects[$i] = Koha::ApiKey->_new_from_dbic($dbix_objects[$i]);
    }

    return \@dbix_objects;
}

=head getApiKey

    my $apiKey = $borrower->getApiKeys( $activeOnly );

=cut

sub getApiKey {
    my ($self, $activeOnly) = @_;

    my $dbix_object = $self->_result()->api_keys({active => 1})->next();
    my $object = Koha::ApiKey->_new_from_dbic($dbix_object);

    return $object;
}

=head swaggerize

    my $swag_borrower = Koha::Borrower->swaggerize();

Turns a ambivalent and confusing Perl-object into a typed object ready for API traversal.
Casts object properties to satisfy Swagger2 data types.

=cut

sub swaggerize {
    my ($self) = @_;
    my $swag = $self->unblessed;

    $swag->{borrowernumber} = 0+$swag->{borrowernumber};

    return $swag;
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
