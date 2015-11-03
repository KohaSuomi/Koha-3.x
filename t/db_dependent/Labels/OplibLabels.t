#!/usr/bin/perl
#
# Copyright 2015 KohaSuomi
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
use Test::More;

use MARC::Record;

use C4::Context;
use C4::Labels::OplibLabels;

# Start transaction
my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

#######################
##Set up test context##
#######################

my $xmlVideo = <<MARC;
<record format="MARC21" type="Bibliographic">
  <leader>01998ngm a2200493 a 4500</leader>
  <controlfield tag="001" ind1=" " ind2=" ">0B2E34B0-0634-446D-9C78-2C93C2896817</controlfield>
  <controlfield tag="003" ind1=" " ind2=" ">KIRKAS</controlfield>
  <controlfield tag="005" ind1=" " ind2=" ">2015-05-07 18:02:45.703</controlfield>
  <controlfield tag="007" ind1=" " ind2=" ">vd|cv||||</controlfield>
  <controlfield tag="008" ind1=" " ind2=" ">140107r20142013fi ||||c |||||||||z|eng| </controlfield>
  <datafield tag="024" ind1="3" ind2=" ">
    <subfield code="a">6438194069918</subfield>
  </datafield>
  <datafield tag="041" ind1="1" ind2=" ">
    <subfield code="a">eng</subfield>
    <subfield code="h">eng</subfield>
    <subfield code="j">fin</subfield>
    <subfield code="j">dan</subfield>
    <subfield code="j">nor</subfield>
    <subfield code="j">swe</subfield>
  </datafield>
  <datafield tag="084" ind1=" " ind2=" ">
    <subfield code="2">ykl</subfield>
    <subfield code="a">84.2</subfield>
  </datafield>
  <datafield tag="130" ind1="0" ind2=" ">
    <subfield code="a">Adore</subfield>
  </datafield>
  <datafield tag="245" ind1="1" ind2="0">
    <subfield code="a">Perfect mothers</subfield>
    <subfield code="c">written and directed by Anne Fontaine ; produced by Philippe Carcassonne, Michel Feller, Andrew Mason.</subfield>
    <subfield code="h">[Videotallenne] /</subfield>
  </datafield>
  <datafield tag="260" ind1=" " ind2=" ">
    <subfield code="a">[Mustasaari] :</subfield>
    <subfield code="b">[Atlantic Film, jakaja],</subfield>
    <subfield code="c">[2014]</subfield>
  </datafield>
  <datafield tag="942" ind1=" " ind2=" ">
    <subfield code="1">2014-01-14 23:28:24.210</subfield>
    <subfield code="c">DV</subfield>
  </datafield>
</record>
MARC
my $recordVideo = MARC::Record->new_from_xml( $xmlVideo, 'utf8', 'MARC21' );

my $xmlRecordingNonFillingCharacters = <<MARC;
<record format="MARC21" type="Bibliographic">
  <leader>00488nja a2200121 a 4500</leader>
  <controlfield tag="001" ind1=" " ind2=" ">68E5A732-770F-4B9A-8F01-173624844160</controlfield>
  <controlfield tag="003" ind1=" " ind2=" ">KIRKAS</controlfield>
  <controlfield tag="005" ind1=" " ind2=" ">2011-07-14 18:12:16.553</controlfield>
  <controlfield tag="007" ind1=" " ind2=" ">sd||||g|||m||d</controlfield>
  <controlfield tag="008" ind1=" " ind2=" ">110302s2010    xxkmp||||||||||||||||||| </controlfield>
  <datafield tag="240" ind1="1" ind2="3">
    <subfield code="a">Un homme et une femme</subfield>
  </datafield>
  <datafield tag="245" ind1="1" ind2="2">
    <subfield code="a">A man and a woman.</subfield>
  </datafield>
  <datafield tag="260" ind1=" " ind2=" ">
    <subfield code="c">2010</subfield>
  </datafield>
</record>
MARC
my $recordRecordingNonFillingCharacters = MARC::Record->new_from_xml( $xmlRecordingNonFillingCharacters, 'utf8', 'MARC21' );

my $xmlRecordingNoFill = <<MARC;
<record format="MARC21" type="Bibliographic">
  <leader>00460nja a2200109 a 4500</leader>
  <controlfield tag="001" ind1=" " ind2=" ">123177CD-9642-4F8A-9BEE-1899AF27E140</controlfield>
  <controlfield tag="003" ind1=" " ind2=" ">KIRKAS</controlfield>
  <controlfield tag="005" ind1=" " ind2=" ">2011-07-14 18:11:56.267</controlfield>
  <controlfield tag="007" ind1=" " ind2=" ">sd||||g|||m||d</controlfield>
  <controlfield tag="008" ind1=" " ind2=" ">110302s2010    xxkmp||||||||||||||||||| </controlfield>
  <datafield tag="245" ind1="1" ind2="0">
    <subfield code="a">Vertigo :</subfield>
    <subfield code="b">Scene d'amour.</subfield>
  </datafield>
</record>
MARC
my $recordRecordingNoFill = MARC::Record->new_from_xml( $xmlRecordingNoFill, 'utf8', 'MARC21' );

my $xmlBook = <<MARC;
<record format="MARC21" type="Bibliographic">
  <leader>00566cam a22002054a 4500</leader>
  <controlfield tag="001" ind1=" " ind2=" ">00043CE6-0104-11D2-B24C-00104B5471B8</controlfield>
  <controlfield tag="003" ind1=" " ind2=" ">KIRKAS</controlfield>
  <controlfield tag="005" ind1=" " ind2=" ">2004-11-07 01:31:00.000</controlfield>
  <controlfield tag="008" ind1=" " ind2=" ">      s1976    at |||||||||||||||||eng|c</controlfield>
  <datafield tag="020" ind1=" " ind2=" ">
    <subfield code="a">0-905368-02-9</subfield>
    <subfield code="q">sid.</subfield>
  </datafield>
  <datafield tag="041" ind1="0" ind2=" ">
    <subfield code="a">eng</subfield>
  </datafield>
  <datafield tag="084" ind1=" " ind2=" ">
    <subfield code="a">75.12</subfield>
  </datafield>
  <datafield tag="100" ind1=" " ind2=" ">
    <subfield code="a">Engen, Rodney K.</subfield>
  </datafield>
  <datafield tag="245" ind1="1" ind2="0">
    <subfield code="a">Randolph caldecott /</subfield>
    <subfield code="b">Lord of the nursery.</subfield>
    <subfield code="c">Rodney K. Engen :</subfield>
  </datafield>
  <datafield tag="942" ind1=" " ind2=" ">
    <subfield code="1">1995-09-04 00:00:00.000</subfield>
    <subfield code="c">KI</subfield>
  </datafield>
</record>
MARC
my $recordBook = MARC::Record->new_from_xml( $xmlBook, 'utf8', 'MARC21' );

subtest "Get Signum" => \&getSignum;
sub getSignum {
    my $signum;

    $signum = C4::Labels::OplibLabels::getSignum($recordVideo);
    is($signum, 'PER', "Signum from video recording, Perfect mothers.");
    $signum = C4::Labels::OplibLabels::getSignum($recordRecordingNoFill);
    is($signum, 'VER', "Signum from musical recording, Vertigo.");
    $signum = C4::Labels::OplibLabels::getSignum($recordRecordingNonFillingCharacters);
    is($signum, 'MAN', "Signum from musical recording with non-filling characters, A man and a woman.");
    $signum = C4::Labels::OplibLabels::getSignum($recordBook);
    is($signum, 'ENG', "Signum from book, Randolph caldecott.");
}

$dbh->rollback;
