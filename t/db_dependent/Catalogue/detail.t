#!/usr/bin/perl

# Copyright 2015 Open Source Freedom Fighters
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More;
use Scalar::Util qw(blessed);

use t::lib::Page::Catalogue::Detail;
use t::lib::TestObjects::BorrowerFactory;
use t::lib::TestObjects::BiblioFactory;
use Koha::Auth::PermissionManager;


##Setting up the test context
my $testContext = {};

my $password = '1234';
my $borrowerFactory = t::lib::TestObjects::BorrowerFactory->new();
my $borrowers = $borrowerFactory->createTestGroup([
            {firstname  => 'Polli-Pantti',
             surname    => 'Pipi',
             cardnumber => '1A01',
             branchcode => 'CPL',
             userid     => 'pipi_padmin',
             password   => $password,
            },
        ], undef, $testContext);

##Test context set, starting testing:
eval { #run in a eval-block so we don't die without tearing down the test context

    subtest "Test Delete Biblio" => sub {
        testDeleteBiblio();
    };

};
if ($@) { #Catch all leaking errors and gracefully terminate.
    warn $@;
    tearDown();
    exit 1;
}

##All tests done, tear down test context
tearDown();
done_testing;

sub tearDown {
    t::lib::TestObjects::ObjectFactory->tearDownTestContext($testContext);
}

sub testDeleteBiblio {
    my $permissionManager = Koha::Auth::PermissionManager->new();
    $permissionManager->grantPermissions($borrowers->{'1A01'}, {catalogue => 'staff_login',
                                                                editcatalogue => 'delete_catalogue',
                                                              });
    my $biblios = t::lib::TestObjects::BiblioFactory->createTestGroup(
                        {'biblio.title' => 'The significant chore of building test faculties',
                         'biblio.author'   => 'Programmer, Broken',
                         'biblio.copyrightdate' => '2015',
                         'biblioitems.isbn'     => '951967151337',
                         'biblioitems.itemtype' => 'BK',
                        }, undef, $testContext);

    my $detail = t::lib::Page::Catalogue::Detail->new({biblionumber => $biblios->{'951967151337'}->{biblionumber}});

    $detail->doPasswordLogin($borrowers->{'1A01'}->userid, $password)
                ->isBiblioMatch($biblios->{'951967151337'})
                ->deleteBiblio();

    my $record = C4::Biblio::GetBiblio( $biblios->{'951967151337'}->{biblionumber} );
    ok(not($record), "Biblio deletion confirmed");
}