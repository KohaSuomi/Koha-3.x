# Copyright Vaara-kirjastot 2015
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
@floatingMatrix
Feature: Floating matrix usage
 We need to be able to share collections across branch boundaries.
 Eg. a bookmobile and the parent library can float the collection to easily move
 Items from the library to the bookmobile and vice-versa.
 So we want some Items to stay in the branch where they have been checked-in and
 want to prevent some Items from staying in the checked-in branch.
 By default if there is no rule, then we use default Koha behaviour.

 Scenario: Set up feature context
  Given the Koha-context, we can proceed with other scenarios.
   | firstName  | surname   | branchCode | branchName | userFlags | userEmail          | branchPrinter |
   | Olli-Antti | Kivilahti | CPL        | CeePeeLib  | 0         | helpme@example.com |               |
  And the following system preferences
   | systemPreference    | value |
   | AutomaticItemReturn | 1     |
  And a set of Borrowers
   | cardnumber | branchcode | categorycode | surname | firstname | address | guarantorbarcode | dateofbirth |
   | 111A0001   | CPL        | S            | Costly  | Colt      | Strt 11 |                  | 1985-10-10  |
   | 222A0002   | FFL        | S            | Costly  | Caleb     | Strt 11 | 111A0001         | 2005-12-12  |
  And a set of Biblios
   | biblio.title             | biblio.author  | biblio.copyrightdate | biblioitems.isbn | biblioitems.itemtype |
   | I wish I met your mother | Pertti Kurikka | 1960                 | 9519671580       | BK                   |
  And a set of Items
   | barcode  | holdingbranch | homebranch | price | replacementprice | itype | biblioisbn |
   | 111N0001 | IPT           | CPL        | 0.50  | 0.50             | BK    | 9519671580 |
   | 111N0002 | CPL           | CPL        | 0.50  | 0.50             | BK    | 9519671580 |
   | 222N0001 | CPL           | FFL        | 1.50  | 1.50             | BK    | 9519671580 |
   | 222N0002 | CPL           | FFL        | 1.50  | 1.50             | BK    | 9519671580 |
   | 222N0003 | IPT           | FFL        | 1.50  | 1.50             | BK    | 9519671580 |
   | 333N0001 | IPT           | IPT        | 1.50  | 1.50             | BK    | 9519671580 |
   | 333N0002 | CPL           | IPT        | 1.50  | 1.50             | CF    | 9519671580 |
   | 333N0003 | CPL           | IPT        | 1.50  | 1.50             | BK    | 9519671580 |

 Scenario: Check if Items float as unit test
  Given a set of Floating matrix rules
    | fromBranch | toBranch | floating    | conditionRules        |
    | CPL        | FFL      | ALWAYS      |                       |
    | IPT        | FFL      | POSSIBLE    |                       |
    | CPL        | IPT      | CONDITIONAL | itype ne CF           |
  When I test if given Items can float, then I see if this feature works!
   | barcode  | fromBranch | toBranch | floatCheck     |
   | 111N0001 | IPT        | CPL      | no_rule        |
   | 111N0002 | CPL        | CPL      | same_branch    |
   | 222N0001 | CPL        | FFL      | ALWAYS         |
   | 222N0002 | CPL        | FFL      | ALWAYS         |
   | 222N0003 | IPT        | FFL      | POSSIBLE       |
   | 333N0001 | IPT        | IPT      | same_branch    |
   | 333N0002 | CPL        | IPT      | fail_condition |
   | 333N0003 | CPL        | IPT      | ALWAYS         |

 Scenario: Check can Items float or not as unit test.
  Given a set of Issues, checked out from the Items' current 'holdingbranch'
    | cardnumber | barcode  | daysOverdue |
    | 111A0001   | 111N0001 | -7          |
    | 111A0001   | 111N0002 | -7          |
    | 111A0001   | 222N0001 | -7          |
    | 111A0001   | 222N0002 | -7          |
    | 111A0001   | 222N0003 | -7          |
    | 111A0001   | 333N0001 | -7          |
    | 111A0001   | 333N0002 | -7          |
    | 111A0001   | 333N0003 | -7          |
  And a set of Floating matrix rules
    | fromBranch | toBranch | floating    | conditionRules |
    | CPL        | FFL      | ALWAYS      |                |
    | IPT        | FFL      | POSSIBLE    |                |
    | CPL        | IPT      | CONDITIONAL | itype ne CF    |
  When checked-out Items are checked-in to their 'holdingbranch'
  Then the following Items are in-transit
    | barcode  | fromBranch | toBranch |
    | 111N0001 | IPT        | CPL      |
    | 333N0002 | CPL        | IPT      |
  #This Item is checked in to the same branch so we don't transfer it
  # | 111N0002 | CPL        | CPL      |
  #This route is always set to float.
  # | 222N0001 | CPL        | FFL      |
  # | 222N0002 | CPL        | FFL      |
  #This route is set to possibly float, so by default it floats.
  # | 222N0003 | IPT        | FFL      |
  #There is no route definition, so we transfer, but we don't transfer from home to home.
  # | 333N0001 | IPT        | IPT      |
  #Conditional route definition, this matches the condition so we don't transfer.
  # | 333N0003 | CPL        | IPT      |

 Scenario: Tear down any database additions from this feature
  When all scenarios are executed, tear down database changes.
