package Koha::Borrowers;

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
use Scalar::Util qw(blessed);
use Try::Tiny;

use Carp;

use Koha::Database;
use Koha::AuthUtils;
use Koha::Borrower;

use Koha::Exception::UnknownObject;

use base qw(Koha::Objects);

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

sub object_class {
    return 'Koha::Borrower';
}

=head cast

    my $borrower = Koha::Borrowers->cast('cardnumber');
    my $borrower = Koha::Borrowers->cast($Koha::Borrower);
    my $borrower = Koha::Borrowers->cast('userid');
    my $borrower = Koha::Borrowers->cast('borrowernumber');
    my $borrower = Koha::Borrowers->cast({borrowernumber => 123,
                                                });
    my $borrower = Koha::Borrowers->cast({firstname => 'Olli-Antti',
                                                    surname => 'Kivi',
                                                    address => 'Koskikatu 25',
                                                });

Because there are gazillion million ways in Koha to invoke a Borrower, this is a
omnibus for easily creating a Borrower-object from all the arcane invocations present
in many parts of Koha.
Just throw the crazy and unpredictable return values from myriad subroutines returning
some kind of an borrowerish value to this casting function to get a brand new Koha::Borrower.
@PARAM1 Scalar, or HASHRef.
@RETURNS Koha::Borrower, possibly already in DB or a completely new one if nothing was
                         inferred from the DB.
@THROWS Koha::Exception::BadParameter, if no idea what to do with the input.
@THROWS Koha::Exception::UnknownObject, if we cannot find a Borrower with the given input.
=cut

sub cast {
    my ($class, $input) = @_;

    my $borrower;
    try {
        $borrower = $class->SUPER::cast($input);
    } catch {
        if (blessed($_) && $_->isa('Koha::Exception::UnknownObject')) {
            $borrower = Koha::AuthUtils::checkKohaSuperuserFromUserid($input);
            unless ($borrower) {
                $_->rethrow();
            }
        }
        else {
            die $_;
        }
    };

    return $borrower;
}
sub _get_castable_unique_columns {
    return ['borrowernumber', 'cardnumber', 'userid'];
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
