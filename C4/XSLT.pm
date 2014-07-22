package C4::XSLT;
# Copyright (C) 2006 LibLime
# <jmf at liblime dot com>
# Parts Copyright Katrin Fischer 2011
# Parts Copyright ByWater Solutions 2011
# Parts Copyright Biblibre 2012
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

use strict;
use warnings;

use C4::Context;
use C4::Branch;
use C4::Items;
use C4::Koha;
use C4::Biblio;
use C4::Circulation;
use C4::Reserves;
use Encode;
use XML::LibXML;
use XML::LibXSLT;
use LWP::Simple;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    require Exporter;
    $VERSION = 3.07.00.049;
    @ISA = qw(Exporter);
    @EXPORT = qw(
        &XSLTParse4Display
        &GetURI
    );
}

=head1 NAME

C4::XSLT - Functions for displaying XSLT-generated content

=head1 FUNCTIONS

=head2 GetURI

GetURI file and returns the xslt as a string

=cut

sub GetURI {
    my ($uri) = @_;
    my $string;
    $string = get $uri ;
    return $string;
}

=head2 transformMARCXML4XSLT

Replaces codes with authorized values in a MARC::Record object

=cut

sub transformMARCXML4XSLT {
    my ($biblionumber, $record) = @_;
    my $frameworkcode = GetFrameworkCode($biblionumber) || '';
    my $tagslib = &GetMarcStructure(1,$frameworkcode);
    my @fields;
    # FIXME: wish there was a better way to handle exceptions
    eval {
        @fields = $record->fields();
    };
    if ($@) { warn "PROBLEM WITH RECORD"; next; }
    my $av = getAuthorisedValues4MARCSubfields($frameworkcode);
    foreach my $tag ( keys %$av ) {
        foreach my $field ( $record->field( $tag ) ) {
            if ( $av->{ $tag } ) {
                my @new_subfields = ();
                for my $subfield ( $field->subfields() ) {
                    my ( $letter, $value ) = @$subfield;
                    $value = GetAuthorisedValueDesc( $tag, $letter, $value, '', $tagslib )
                        if $av->{ $tag }->{ $letter };
                    push( @new_subfields, $letter, $value );
                } 
                $field ->replace_with( MARC::Field->new(
                    $tag,
                    $field->indicator(1),
                    $field->indicator(2),
                    @new_subfields
                ) );
            }
        }
    }
    return $record;
}

=head2 getAuthorisedValues4MARCSubfields

Returns a ref of hash of ref of hash for tag -> letter controled by authorised values

=cut

# Cache for tagfield-tagsubfield to decode per framework.
# Should be preferably be placed in Koha-core...
my %authval_per_framework;

sub getAuthorisedValues4MARCSubfields {
    my ($frameworkcode) = @_;
    unless ( $authval_per_framework{ $frameworkcode } ) {
        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare("SELECT DISTINCT tagfield, tagsubfield
                                 FROM marc_subfield_structure
                                 WHERE authorised_value IS NOT NULL
                                   AND authorised_value!=''
                                   AND frameworkcode=?");
        $sth->execute( $frameworkcode );
        my $av = { };
        while ( my ( $tag, $letter ) = $sth->fetchrow() ) {
            $av->{ $tag }->{ $letter } = 1;
        }
        $authval_per_framework{ $frameworkcode } = $av;
    }
    return $authval_per_framework{ $frameworkcode };
}

my $stylesheet;

sub _get_best_default_xslt_filename {
    my ($htdocs, $theme, $lang, $base_xslfile) = @_;

    my @candidates = (
        "$htdocs/$theme/$lang/xslt/${base_xslfile}", # exact match
        "$htdocs/$theme/en/xslt/${base_xslfile}",    # if not, preferred theme in English
        "$htdocs/prog/$lang/xslt/${base_xslfile}",   # if not, 'prog' theme in preferred language
        "$htdocs/prog/en/xslt/${base_xslfile}",      # otherwise, prog theme in English; should always
                                                     # exist
    );
    my $xslfilename;
    foreach my $filename (@candidates) {
        $xslfilename = $filename;
        if (-f $filename) {
            last; # we have a winner!
        }
    }
    return $xslfilename;
}

sub XSLTParse4Display {
    my ( $biblionumber, $orig_record, $xslsyspref, $fixamps, $hidden_items ) = @_;

    my $shouldIPullInComponentPartRecords; #We don't want to pull component part records if they are not needed! Show component part records only for detailed views.

    my $xslfilename = C4::Context->preference($xslsyspref);
    if ( $xslfilename =~ /^\s*"?default"?\s*$/i ) {
        my $htdocs;
        my $theme;
        my $lang = C4::Templates::_current_language();
        my $xslfile;
        if ($xslsyspref eq "XSLTDetailsDisplay") {
            $htdocs  = C4::Context->config('intrahtdocs');
            $theme   = C4::Context->preference("template");
            $xslfile = C4::Context->preference('marcflavour') .
                       "slim2intranetDetail.xsl";
        } elsif ($xslsyspref eq "XSLTResultsDisplay") {
            $htdocs  = C4::Context->config('intrahtdocs');
            $theme   = C4::Context->preference("template");
            $xslfile = C4::Context->preference('marcflavour') .
                        "slim2intranetResults.xsl";
        } elsif ($xslsyspref eq "OPACXSLTDetailsDisplay") {
            $htdocs  = C4::Context->config('opachtdocs');
            $theme   = C4::Context->preference("opacthemes");
            $xslfile = C4::Context->preference('marcflavour') .
                       "slim2OPACDetail.xsl";
        } elsif ($xslsyspref eq "OPACXSLTResultsDisplay") {
            $htdocs  = C4::Context->config('opachtdocs');
            $theme   = C4::Context->preference("opacthemes");
            $xslfile = C4::Context->preference('marcflavour') .
                       "slim2OPACResults.xsl";
        }
        $xslfilename = _get_best_default_xslt_filename($htdocs, $theme, $lang, $xslfile);
    }

    if ( $xslfilename =~ m/\{langcode\}/ ) {
        my $lang = C4::Templates::_current_language();
        $xslfilename =~ s/\{langcode\}/$lang/;
    }

    ##Enable component part injection for Details XSLTs.
    if ( $xslsyspref =~ m/Details/ ) {
        $shouldIPullInComponentPartRecords = 1;
    }


    # grab the XML, run it through our stylesheet, push it out to the browser
    my $record = transformMARCXML4XSLT($biblionumber, $orig_record);
    my $f001Data = $record->field('001');
    $f001Data = $f001Data->data() if defined $f001Data; #Not all records have the field 001??
    my $f003Data = $record->field('003');
    $f003Data = $f003Data->data() if defined $f003Data; #Not all records have the field 003??

    my $componentPartRecordsXML = '';
    $componentPartRecordsXML = _prepareComponentPartRecords($f001Data, $f003Data) if $shouldIPullInComponentPartRecords &&
                                                            C4::Context->preference('AddComponentPartRecordsToDetailedViews');;

    #return $record->as_formatted();
    my $itemsxml  = buildKohaItemsNamespace($biblionumber, $hidden_items);
    my $xmlrecord = $record->as_xml(C4::Context->preference('marcflavour'));
    my $sysxml = "<sysprefs>\n";
    foreach my $syspref ( qw/ hidelostitems OPACURLOpenInNewWindow
                              DisplayOPACiconsXSLT URLLinkText viewISBD
                              OPACBaseURL TraceCompleteSubfields UseICU
                              UseAuthoritiesForTracings TraceSubjectSubdivisions
                              Display856uAsImage OPACDisplay856uAsImage 
                              UseControlNumber IntranetBiblioDefaultView BiblioDefaultView
                              singleBranchMode OPACItemLocation DisplayIconsXSLT
                              AlternateHoldingsField AlternateHoldingsSeparator
                              TrackClicks / )
    {
        my $sp = C4::Context->preference( $syspref );
        next unless defined($sp);
        $sysxml .= "<syspref name=\"$syspref\">$sp</syspref>\n";
    }
    $sysxml .= "</sysprefs>\n";
    $xmlrecord =~ s/\<\/record\>/$itemsxml$sysxml$componentPartRecordsXML\<\/record\>/;
    if ($fixamps) { # We need to correct the ampersand entities that Zebra outputs
        $xmlrecord =~ s/\&amp;amp;/\&amp;/g;
        $xmlrecord =~ s/\&amp\;lt\;/\&lt\;/g;
        $xmlrecord =~ s/\&amp\;gt\;/\&gt\;/g;
    }
    $xmlrecord =~ s/\& /\&amp\; /;
    $xmlrecord =~ s/\&amp\;amp\; /\&amp\; /;

    my $parser = XML::LibXML->new();
    # don't die when you find &, >, etc
    $parser->recover_silently(0);
    my $source = $parser->parse_string($xmlrecord);
    unless ( $stylesheet->{$xslfilename} ) {
        my $xslt = XML::LibXSLT->new();
        my $style_doc;
        if ( $xslfilename =~ /^https?:\/\// ) {
            my $xsltstring = GetURI($xslfilename);
            $style_doc = $parser->parse_string($xsltstring);
        } else {
            use Cwd;
            $style_doc = $parser->parse_file($xslfilename);
        }
        $stylesheet->{$xslfilename} = $xslt->parse_stylesheet($style_doc);
    }
    my $results      = $stylesheet->{$xslfilename}->transform($source);
    my $newxmlrecord = $stylesheet->{$xslfilename}->output_string($results);
    return $newxmlrecord;
}

sub buildKohaItemsNamespace {
    my ($biblionumber, $hidden_items) = @_;

    my @items = C4::Items::GetItemsInfo($biblionumber);
    if ($hidden_items && @$hidden_items) {
        my %hi = map {$_ => 1} @$hidden_items;
        @items = grep { !$hi{$_->{itemnumber}} } @items;
    }

    my $shelflocations = GetKohaAuthorisedValues('items.location',GetFrameworkCode($biblionumber), 'opac');
    my $ccodes         = GetKohaAuthorisedValues('items.ccode',GetFrameworkCode($biblionumber), 'opac');

    my $branches = GetBranches();
    my $itemtypes = GetItemTypes();
    my $location = "";
    my $ccode = "";
    my $xml = '';
    for my $item (@items) {
        my $status;

        my ( $transfertwhen, $transfertfrom, $transfertto ) = C4::Circulation::GetTransfers($item->{itemnumber});

        my $reservestatus = C4::Reserves::GetReserveStatus( $item->{itemnumber} );

        if ( $itemtypes->{ $item->{itype} }->{notforloan} || $item->{notforloan} || $item->{onloan} || $item->{withdrawn} || $item->{itemlost} || $item->{damaged} ||
             (defined $transfertwhen && $transfertwhen ne '') || $item->{itemnotforloan} || (defined $reservestatus && $reservestatus eq "Waiting") ){ 
            if ( $item->{notforloan} < 0) {
                $status = "On order";
            } 
            if ( $item->{itemnotforloan} > 0 || $item->{notforloan} > 0 || $itemtypes->{ $item->{itype} }->{notforloan} == 1 ) {
                $status = "reference";
            }
            if ($item->{onloan}) {
                $status = "Checked out";
            }
            if ( $item->{withdrawn}) {
                $status = "Withdrawn";
            }
            if ($item->{itemlost}) {
                $status = "Lost";
            }
            if ($item->{damaged}) {
                $status = "Damaged"; 
            }
            if (defined $transfertwhen && $transfertwhen ne '') {
                $status = 'In transit';
            }
            if (defined $reservestatus && $reservestatus eq "Waiting") {
                $status = 'Waiting';
            }
        } else {
            $status = "available";
        }
        my $homebranch = $item->{homebranch}? xml_escape($branches->{$item->{homebranch}}->{'branchname'}):'';
        my $holdingbranch = $item->{holdingbranch}? xml_escape($branches->{$item->{holdingbranch}}->{'branchname'}):'';
        $location = $item->{location}? xml_escape($shelflocations->{$item->{location}}||$item->{location}):'';
        $ccode = $item->{ccode}? xml_escape($ccodes->{$item->{ccode}}||$item->{ccode}):'';
        my $itemcallnumber = xml_escape($item->{itemcallnumber});
        $xml.= "<item><homebranch>$homebranch</homebranch>".
                "<holdingbranch>$holdingbranch</holdingbranch>".
                "<location>$location</location>".
                "<ccode>$ccode</ccode>".
		"<status>$status</status>".
		"<itemcallnumber>".$itemcallnumber."</itemcallnumber>"
        . "</item>";

    }
    $xml = "<items xmlns=\"http://www.koha-community.org/items\">".$xml."</items>";
    return $xml;
}

=head

  Finds all the component parts targeting the parents fields 001 and optionally 003.
  Strips some key identifiers from those records.
  Builds a XML presentation out of those, ready for the XSLT processing.

  $componentPartRecordsXML = &_prepareComponentPartRecords($f001Data, $f003Data);

  Returns: a string containing an XML representation of component part records
           In XSL: componentPartRecords/componentPart/title
           in addition to title, elements can also be unititle, biblionumber, author, publishercode, publicationyear
           eg. componentPartRecords/componentPart/biblionumber

=cut
sub _prepareComponentPartRecords {

    my ($f001Data, $f003Data) = @_;
    my $componentPartBiblios = C4::Biblio::getComponentRecords( $f001Data, $f003Data );

    if (@$componentPartBiblios) {

        #Collect the XML elements to a array instead of continuously concatenating a string.
        #  There might be dozens of component part records and in such a case string concatenation is extremely slow.
        my @componentPartRecordXML = ('<componentPartRecords>');
        for my $cb ( @{$componentPartBiblios} ) {
            push @componentPartRecordXML, '  <componentPart>';


            push @componentPartRecordXML, '    <title>'.xml_escape($cb->{'title'}).'</title>'                               if $cb->{'title'};
            push @componentPartRecordXML, '    <unititle>'.xml_escape($cb->{'unititle'}).'</unititle>'                      if $cb->{'unititle'};
            push @componentPartRecordXML, '    <biblionumber>'.xml_escape($cb->{'biblionumber'}).'</biblionumber>'          if $cb->{'biblionumber'};
            push @componentPartRecordXML, '    <author>'.xml_escape($cb->{'author'}).'</author>'                            if $cb->{'author'};
            push @componentPartRecordXML, '    <publishercode>'.xml_escape($cb->{'publishercode'}).'</publishercode>'       if $cb->{'publishercode'};
            push @componentPartRecordXML, '    <publicationyear>'.xml_escape($cb->{'publicationyear'}).'</publicationyear>' if $cb->{'publicationyear'};

            push @componentPartRecordXML, '  </componentPart>';
        }
        push @componentPartRecordXML, '</componentPartRecords>';
        push @componentPartRecordXML, ''; #Just to make the join operation end with a newline

        #Build the real XML string.
        return join "\n", @componentPartRecordXML;
    }
    return ''; #Instantiate this string so we don't get undefined errors when concatenating with this.
}


1;
__END__

=head1 NOTES

=cut

=head1 AUTHOR

Joshua Ferraro <jmf@liblime.com>

=cut
