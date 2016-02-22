package t::db_dependent::Api::V1::Records;

# Copyright 2016 KohaSuomi
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
use MARC::Record;

use C4::Biblio;
use C4::Context;

use t::db_dependent::Api::V1::Biblios;
use t::lib::TestObjects::BiblioFactory;

sub post200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my $testMarcxml = <<MARCXML;
<record>
  <leader>00510cam a22002054a 4500</leader>
  <controlfield tag="001">rest-test-record</controlfield>
  <controlfield tag="003">REST-TEST</controlfield>
  <controlfield tag="008">       1988    xxk|||||||||| ||||1|eng|c</controlfield>
  <datafield tag="020" ind1=" " ind2=" ">
    <subfield code="a">rest-test-isbn</subfield>
  </datafield>
  <datafield tag="245" ind1="1" ind2="4">
    <subfield code="a">REST recordzzz</subfield>
  </datafield>
</record>
MARCXML
    my ($path, $record, $biblionumber, $ua, $tx, $json);

    $path = $restTest->get_routePath();
    #Make a custom POST request with formData parameters :) Mojo-fu!
    $ua = $driver->ua;
    $tx = $ua->build_tx(POST => $path => {Accept => '*/*'});
    $tx->req->body( Mojo::Parameters->new("marcxml=$testMarcxml")->to_string);
    $tx->req->headers->remove('Content-Type');
    $tx->req->headers->add('Content-Type' => 'application/x-www-form-urlencoded');
    $tx = $ua->start($tx);
    $restTest->catchSwagger2Errors($tx);
    $json = $tx->res->json;
    is($tx->res->code, 200, "Good parameters given");
    is(ref($json), 'HASH', "Got a json-object");

    $biblionumber = $json->{biblionumber};
    ok($json->{biblionumber}, "Got the biblionumber!");

    $record = MARC::Record->new_from_xml($json->{marcxml}, 'utf8', C4::Context->preference("marcflavour"));
    is($record->subfield('020', 'a'), 'rest-test-isbn', 'Got the ISBN!');

    is($json->{links}->[0]->{ref}, 'self.nativeView', 'Received HATEOAS link reference');
    ok($json->{links}->[0]->{href} =~ m!/cgi-bin/koha/catalogue/detail\.pl\?biblionumber=$biblionumber!, 'Received HATEOAS link to home');

    #Finally tear down changes
    C4::Biblio::DelBiblio($biblionumber);
}

sub post400 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my $testMarcxml = <<MARCXML;
<record>
  <leader>00510cam a22002054a 4500</leader>
  <controlfield tag="008">       1988    xxk|||||||||| ||||1|eng|c</controlfield>
  <datafield tag="245" ind1="1" ind2="4">
    <subfield code="a">Missing 001 and 003m which is bad!</subfield>
  </datafield>
</record>
MARCXML
    my ($path, $biblionumber, $tx, $ua, $json);

    $path = $restTest->get_routePath();
    #Make a custom POST request with formData parameters :) Mojo-fu!
    $ua = $driver->ua;
    $tx = $ua->build_tx(POST => $path => {Accept => '*/*'});
    $tx->req->body( Mojo::Parameters->new("marcxml=$testMarcxml")->to_string);
    $tx->req->headers->remove('Content-Type');
    $tx->req->headers->add('Content-Type' => 'application/x-www-form-urlencoded');
    $tx = $ua->start($tx);
    $restTest->catchSwagger2Errors($tx);
    $json = $tx->res->json;
    is($tx->res->code, 400, "Good parameters given");
    is(ref($json), 'HASH', "Got a json-object");

    ok($json->{error} =~ /One of mandatory fields '.*?' missing/, 'Mandatory 001 and 003 is missing');
}

sub post500 {
    ok(1, 'skipped');
}

sub get_n_200 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path, $biblio, $biblionumber);

    #Create the test context.
    $biblio = t::lib::TestObjects::BiblioFactory->createTestGroup(
                        {'biblio.title' => 'The significant chore of building test faculties',
                         'biblio.author'   => 'Programmer, Broken',
                         'biblio.copyrightdate' => '2015',
                         'biblioitems.isbn'     => '951967151337',
                         'biblioitems.itemtype' => 'BK',
                        }, undef, $testContext);
    $biblionumber = $biblio->{biblionumber};

    #Execute request
    $path = $restTest->get_routePath($biblionumber);
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(200);

    #Confirm result
    $driver->json_is('/biblionumber', $biblionumber);
    $driver->json_like('/marcxml', qr(Programmer, Broken));
}

sub get_n_404 {
    my ($class, $restTest, $driver) = @_;
    my $testContext = $restTest->get_testContext(); #Test context will be automatically cleaned after this subtest has been executed.
    my $activeUser = $restTest->get_activeBorrower();

    my ($path);

    #Execute request
    $path = $restTest->get_routePath(999999999999);
    $driver->get_ok($path => {Accept => 'text/json'});
    $restTest->catchSwagger2Errors($driver);
    $driver->status_is(404);

    #Confirm result
    $driver->json_is('/biblionumber', undef);
}

use t::lib::TestObjects::BiblioFactory;
use t::lib::TestObjects::ItemFactory;
use t::lib::TestObjects::ObjectFactory;

sub delete_n_204 {
    t::db_dependent::Api::V1::Biblios::delete_n_204(@_);
}

sub delete_n_404 {
    t::db_dependent::Api::V1::Biblios::delete_n_404(@_);
}

sub delete_n_400 {
    t::db_dependent::Api::V1::Biblios::delete_n_400(@_);
}

1;
