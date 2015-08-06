package t::db_dependent::Api::V1::Biblios;

use Modern::Perl;
use Test::More;

use t::lib::TestObjects::BiblioFactory;
use t::lib::TestObjects::ItemFactory;
use t::lib::TestObjects::ObjectFactory;

sub delete_n_204 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    #Create the test context.
    my $biblios = t::lib::TestObjects::BiblioFactory->createTestGroup(
                        {'biblio.title' => 'The significant chore of building test faculties',
                         'biblio.author'   => 'Programmer, Broken',
                         'biblio.copyrightdate' => '2015',
                         'biblioitems.isbn'     => '951967151337',
                         'biblioitems.itemtype' => 'BK',
                        }, undef, $testContext);
    my $biblionumber = $biblios->{'951967151337'}->{biblionumber};

    #Execute request
    my $path = $restTest->get_routePath();
    $path =~ s/\{biblionumber\}/$biblionumber/;
    $driver->delete_ok($path => {Accept => 'text/json'});
    $driver->status_is(204);

    #Confirm result
    my $record = C4::Biblio::GetBiblio( $biblios->{'951967151337'}->{biblionumber} );
    ok(not($record), "Biblio deletion confirmed");

    return 1;
}

sub delete_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    #Create the test context.
    my $biblios = t::lib::TestObjects::BiblioFactory->createTestGroup(
                        {'biblio.title' => 'The significant chore of building test faculties',
                         'biblio.author'   => 'Programmer, Broken',
                         'biblio.copyrightdate' => '2015',
                         'biblioitems.isbn'     => '951967151337',
                         'biblioitems.itemtype' => 'BK',
                        }, undef, $testContext);
    my $biblionumber = $biblios->{'951967151337'}->{biblionumber};
    C4::Biblio::DelBiblio($biblionumber);
    #Now we have a biblionumber which certainly doesn't exists!

    #Execute request
    my $path = $restTest->get_routePath();
    $path =~ s/\{biblionumber\}/$biblionumber/;
    $driver->delete_ok($path => {Accept => 'text/json'});
    $driver->status_is(404);

    return 1;
}

sub delete_n_400 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    #Create the test context.
    my $biblios = t::lib::TestObjects::BiblioFactory->createTestGroup(
                        {'biblio.title' => 'The significant chore of building test faculties',
                         'biblio.author'   => 'Programmer, Broken',
                         'biblio.copyrightdate' => '2015',
                         'biblioitems.isbn'     => '951967151337',
                         'biblioitems.itemtype' => 'BK',
                        }, undef, $testContext);
    my $biblionumber = $biblios->{'951967151337'}->{biblionumber};
    my $items = t::lib::TestObjects::ItemFactory->createTestGroup([
                                {biblionumber => $biblionumber,
                                 barcode => '11N01'}
                                ], undef, $testContext);

    #Execute request
    my $path = $restTest->get_routePath();
    $path =~ s/\{biblionumber\}/$biblionumber/;
    $driver->delete_ok($path => {Accept => 'text/json'});
    $driver->status_is(400);

    #Confirm result
    my $record = C4::Biblio::GetBiblio( $biblios->{'951967151337'}->{biblionumber} );
    ok($record, "Biblio deletion aborted due to attached Items");

    return 1;
}

1;