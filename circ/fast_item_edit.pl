#!/usr/bin/perl

# Copyright 2015 Vaara-kirjastot
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

use CGI;
use Scalar::Util qw(blessed);
use Try::Tiny;

use C4::Context;
use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;

use Koha::Database;

use Koha::Exception::UnknownObject;

my $cgi = new CGI;

my ( $template, $librarian, $cookie ) = get_template_and_user(
    {
        template_name   => "circ/fast_item_edit.tmpl",
        query           => $cgi,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "*" },
    }
);

my $schema = Koha::Database->new()->schema();

#Handle parameters
my $barcode        = $cgi->param('barcode');
my $newBarcode     = $cgi->param('newBarcode');
my $oldBarcode; #Used by the rebarcode to override the given $barcode
my $item; #Derived from $barcode in validateParameters()
my $biblio;

##Collect errors here
my @errors;
##Collect performed actions here
my @actions;
handleRequest();

output_html_with_http_headers( $cgi, $cookie, $template->output );


### REQUEST HANDLING ROUTINES BELOW ###


sub handleRequest {
    try {

        validateParameters();
        rebarcode() if $newBarcode && $newBarcode ne $barcode;

    } catch {
        if (blessed($_)) {
            if ($_->isa('Koha::Exception::UnknownObject')) {
                push @errors, "NO_ITEM";
            }
            else {
                warn $_->error()."\n";
            }
        }
        else { die "Exception not caught by try-catch:> ".$_;}
    };
    #Store parameters for the template round-trip.
    $template->param(   barcode => $barcode,
                        newBarcode => $newBarcode,
                        oldBarcode => $oldBarcode,
                        item => $item,
                        biblio => $biblio,
                    );
    $template->param(   errors  => \@errors  ) if scalar(@errors );
    $template->param(   actions => \@actions ) if scalar(@actions);
}

sub validateParameters {

    validateBarcode() if $barcode;
    $newBarcode =~ s/\s//gsm if $newBarcode;
}

=head validateBarcode
@RETURNS DBIx::Class::ResultSet::Item
@THROWS Koha::Exception::UnknownObject
=cut
sub validateBarcode {
    $barcode =~ s/\s//gsm;
    #Make sure the given barcode matches an Item
    $item = $schema->resultset("Item")->single( { barcode => $barcode } ) if $barcode;
    if ($item) {
        $biblio = C4::Biblio::GetBiblioFromItemNumber($item->itemnumber());
        return $item;
    }
    else {
        Koha::Exception::UnknownObject->throw({error => "No Item with barcode $barcode"});
    }
}

sub rebarcode {
    C4::Items::ModItem({barcode => $newBarcode}, undef, $item->itemnumber());
    push @actions, "REBARCODE";
    $oldBarcode = $barcode;
    $barcode = undef;
}
