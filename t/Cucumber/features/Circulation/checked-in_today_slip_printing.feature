# Copyright KohaSuomi 2016
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
#
################################################################################

######################
### Käyttäjätarina ###
######################
# Kun asiakas haluaa kuitin tänään palauttamastaan aineistosta, se pitäisi
# onnistua kaikista hänen palauttamistaan niteistä huolimatta siitä, minkä
# kirjaston niteitä ne ovat tai mihin ne ovat matkalla. Nyt kuittitoiminto ei
# anna palautuskuittiin toisen toimipisteen niteiden tietoja, vaikka ne on
# juuri palautettu asiakkaan asiointitoimipisteessä.
# Esimerkki: Vipuseen palautetaan lehtiä ja dvd-elokuvia. Asiakas saa
# palautuskuitin vain lehdistä (jotka ovat Vipusen aineistoa), mutta ei
# elokuvista, jotka ovat lainausosaston aineistoa eli niiden kotikirjasto on
# JOE_JOE ja aineisto on matkalla Vipusesta (JOE_JOELT) yläkertaan.

## language: fi
#
#@fast
#Ominaisuus: Palautuskuitin tulostaminen
#  Kirjastovirkailija-Conanina haluan tulostaa helposti palautuskuitin asiakkaan tänään palautetuista niteistä
#
#  Tapaus: Palautuskuitin tulostaminen
#    Oletetaan että 'Matti' on palauttanut seuraavat niteet
#      | kotikirjasto | viivakoodi | aineistolaji | palautuskirjasto | palautuspäivä |
#      | CPL          | 1N01       | KI           | CPL              | tänään        |
#      | FPL          | 2N01       | KI           | CPL              | tänään        |
#      | FPL          | 2N02       | KI           | CPL              | tänään        |
#    Oletetaan että 'Conan' on navigoinut sivulle 'circ/circulation.pl' 'Matin' kanssa.
#    Kun valintaa 'Tulosta tänään palautetut' klikataan
#    Niin 'tänään palautetut -kuitissa' on seuraavat niteet
#      | viivakoodi | kotikirjasto |
#      | 1N01       | CPL          |
#      | 2N01       | FPL          |
#      | 2N02       | FPL          |

#language: en
@fast
Feature: Checked-in today slip printing
  As Conan the librarian I want to easily print a slip of a borrower's today's check-ins.

  Scenario: Printing the checked-in today slip
    Given that 'Matti' has checked-in the following items
      | homebranch | barcode | itype | checkinbranch | checkindate |
      | CPL        | 1N01    | BK    | CPL           | today       |
      | FPL        | 2N01    | BK    | CPL           | today       |
      | FPL        | 2N02    | BK    | CPL           | today       |
    Given that 'Conan' has navigated to 'circ/circulation.pl' with 'Matti'
    When selection 'Print checked-in today -slip' has been clicked
    Then the 'checked-in today -slip' has the following items
      | barcode | homebranch |
      | 1N01    | CPL        |
      | 2N01    | FPL        |
      | 2N02    | FPL        |
