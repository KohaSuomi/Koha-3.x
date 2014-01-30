#!/usr/bin/perl
#
# Copyright 2006 Katipo Communications.
# Parts Copyright 2009 Foundations Bible College.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
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
use utf8;
use vars qw($debug);

use CGI;
use CGI::Cookie;

use C4::Auth qw(get_template_and_user);
use C4::Output qw(output_html_with_http_headers);
use C4::Labels::OplibLabels;

my $cgi = new CGI;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "labels/oplib-label-create.tmpl",
        query           => $cgi,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { catalogue => 1 },
        debug           => 1,
    }
);

my $barcode = $cgi->param('barcode');
my $ignoreErrors = $cgi->param('ignoreErrors');
my $margins = {}; #collect the awsum print margins! yay!
my $marginsCookie = exists $cgi->{'.cookies'}->{'label_margins'} ? $cgi->{'.cookies'}->{'label_margins'} : $cgi->cookie(-name => 'label_margins', -value => '', -expires => '+3M');

#When we are using lableprinter by printing labels, we always get the leftMargin parameter, even when the input field is empty
my $leftMargin = $cgi->param('leftMargin');
if (defined $leftMargin && $leftMargin != 0 && $leftMargin ne '') {
    $margins->{left} = $cgi->param('leftMargin');
    $marginsCookie->{value}->[0] = $margins->{left};
}
elsif (defined $leftMargin) {
    $marginsCookie->{value}->[0] = '';
}
#When we are entering the oplib-label-creator, we have no leftMargin and rely on the cookie to remember the setting
elsif (length $marginsCookie->{value}->[0] > 0) {
    $margins->{left} = $marginsCookie->{value}->[0];
}

if ($margins->{left}) {
    $template->param('margins', $margins);
}


##Barcodes have been submitted! How awesome!
##Separate the barcodes into an array. Then create labels out of them!
if ($barcode) {

    #Sanitate the barcodes! Always sanitate input!! Mon dieu!
    my $barcodes = [split( /\n/, $barcode )];
    for(my $i=0 ; $i<@$barcodes ; $i++){
        $barcodes->[$i] =~ s/^\s*//; #Trim barcode for whitespace.
        $barcodes->[$i] =~ s/\s*$//; #Otherwise very hard to debug!?!!?!?!?
    }

    my ($labelPdfDirectory, $fileName, $badBarcodeErrors) = C4::Labels::OplibLabels::populateAndCreateLabelSheets($barcodes, $margins);
    my $filePathAndName = $labelPdfDirectory.$fileName;

    if ($badBarcodeErrors) {
        $template->param('badBarcodeErrors', $badBarcodeErrors);
        $template->param('barcode', $barcode); #return barcodes if error happens!
        #Being nice might not be such a great idea after all :( $template->param('ignoreErrorsChecked', 'true'); #Be nice and readily check the ignoreErrors-checkbox!
    }

    #If we have no errors or want to ignore them, go ahead and share the pdf!
    if (!($badBarcodeErrors) || $ignoreErrors) {
        sendPdf($cgi, $fileName, $filePathAndName);
        return 1;
    }
}

output_html_with_http_headers $cgi, $marginsCookie, $template->output;

sub sendPdf {
    my ($cgi, $fileName, $filePathAndName) = @_;
      #############################################
    ### Send the pdf to the user as an attachment ###
    print $cgi->header( -type       => 'application/pdf',
                        -cookie     => [$marginsCookie],
                        -encoding   => 'utf-8',
                        -charset    => 'utf-8',
                        -attachment => $fileName,
                      ) if $marginsCookie;
    print $cgi->header( -type       => 'application/pdf',
                        -encoding   => 'utf-8',
                        -charset    => 'utf-8',
                        -attachment => $fileName,
                      ) unless $marginsCookie;

    # slurp temporary filename and print it out for plack to pick up
    local $/ = undef;
    open(my $fh, '<', $filePathAndName) || die "$filePathAndName: $!";
    print <$fh>;
    close $fh;
    unlink $filePathAndName;
    ###              pdf sent hooray!             ###
      #############################################
}