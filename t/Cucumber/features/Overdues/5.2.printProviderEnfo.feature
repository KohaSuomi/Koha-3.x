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
####################################################################################
@enfo
Feature: PrintProviderEnfo interfaces with the Enfo Zender e-printing service.


 @enfo
 Scenario: Set up feature context
  Given the Koha-context, we can proceed with other scenarios.
   | firstName  | surname   | branchCode | branchName | userFlags | userEmail          | branchPrinter |
   | Olli-Antti | Kivilahti | CPL        | CeePeeLib  | 0         | helpme@example.com |               |
  And a set of letter templates
   | module      | code  | branchcode | name    | is_html | title  | message_transport_types | content                                 |
   | circulation | ODUE1 |            | Notice1 |         | Title1 | print                   | EPL 1st. letter\n20<<borrowers.cardnumber>>\n<item>31<<biblio.title>>\n 1Barcode: <<items.barcode>> <<issues.date_due>></item> |
   | circulation | ODUEF |            | Fail1   |         | Fail1  | print                   | EPL failing\n20<<borrowers.cardnumber>>\n<item>31<<biblio.title>>\n\n Barcode: <<items.barcode>> <<issues.date_due>></item> |
   | circulation | ODUE2 |            | Notice2 |         | Title2 | print                   | EPL 2nd. letter\n20<<borrowers.cardnumber>>\n<item>31<<biblio.title>>\n 1Barcode: <<items.barcode>> <<issues.date_due>></item> |
   | circulation | ODUE3 |            | Notice3 |         | Title3 | print                   | EPL 3rd. letter\n20<<borrowers.cardnumber>>\n<item>31<<biblio.title>>\n 1Barcode: <<items.barcode>> <<issues.date_due>></item> |
  And a set of overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   |            | K                | 1            | print                 | 5     | ODUEF      | 0        | 0.1  |
   |            | K                | 2            | print                 | 10    | ODUE2      | 0        | 0.2  |
   |            | K                | 3            | print                 | 15    | ODUE3      | 0        | 0.3  |
   |            | S                | 1            | print                 | 5     | ODUE1      | 0        | 1.0  |
   |            | PT               | 1            | print                 | 5     | ODUE1      | 0        | 1.1  |
   |            | J                | 1            | print                 | 5     | ODUE1      | 0        | 1.2  |
   |            | ST               | 1            | print                 | 5     | ODUE1      | 0        | 1.3  |
   |            | S                | 2            | print                 | 10    | ODUE2      | 0        | 2.0  |
   |            | PT               | 2            | print                 | 10    | ODUE2      | 0        | 2.1  |
   |            | J                | 2            | print                 | 10    | ODUE2      | 0        | 2.2  |
   |            | ST               | 2            | print                 | 10    | ODUE2      | 0        | 2.3  |
   |            | S                | 3            | print                 | 15    | ODUE3      | 1        | 3.0  |
   |            | PT               | 3            | print                 | 15    | ODUE3      | 1        | 3.1  |
   |            | J                | 3            | print                 | 15    | ODUE3      | 1        | 3.2  |
   |            | ST               | 3            | print                 | 15    | ODUE3      | 1        | 3.3  |
  And a set of Borrowers
   | cardnumber | branchcode | categorycode | surname | firstname | address | guarantorbarcode | dateofbirth |
   | 111A0001   | CPL        | S            | Koivu   | Saku      | Strt 11 |                  | 1985-10-10  |
   | 111A0002   | CPL        | S            | Selanne | Teemu     | Strt 11 |                  | 1985-10-10  |
   | 222A0001   | FFL        | ST           | Valo    | Ville     | Strt 11 |                  | 1991-12-12  |
   | 222A0002   | FFL        | J            | Embuske | Jaana     | Strt 11 | 222A0001         | 2005-12-12  |
   | 333A0001   | IPT        | PT           | Salo    | Mika      | Strt 11 |                  | 1985-10-10  |
   | 333A0002   | IPT        | K            | Salo    | Minna     | Strt 11 | 333A0001         | 2005-12-12  |
  And a set of Biblios
   | biblio.title | biblio.author  | biblio.copyrightdate | biblioitems.isbn | biblioitems.itemtype |
   | I wish       | Pertti Kurikka | 1960                 | 9519671580       | BK                   |
   | How I        | Pertti Kurikka | 1961                 | 9519671581       | BK                   |
   | Did I        | Pertti Kurikka | 1962                 | 9519671582       | BK                   |
  And a set of Items
   | barcode  | homebranch | holdingbranch | price | replacementprice | itype | biblioisbn |
   | 111N0001 | CPL        | IPT           | 0.50  | 0.50             | BK    | 9519671580 |
   | 111N0002 | CPL        | CPL           | 0.50  | 0.50             | BK    | 9519671581 |
   | 111N0003 | CPL        | IPT           | 0.50  | 0.50             | BK    | 9519671582 |
   | 111N0004 | CPL        | IPT           | 0.50  | 0.50             | BK    | 9519671580 |
   | 222N0001 | FFL        | CPL           | 1.00  | 1.00             | BK    | 9519671581 |
   | 222N0002 | FFL        | IPT           | 1.00  | 1.00             | BK    | 9519671582 |
   | 222N0003 | FFL        | CPL           | 1.00  | 1.00             | BK    | 9519671580 |
   | 222N0004 | FFL        | CPL           | 1.00  | 1.00             | BK    | 9519671581 |
   | 333N0001 | IPT        | IPT           | 1.50  | 1.50             | BK    | 9519671582 |
   | 333N0002 | IPT        | CPL           | 1.50  | 1.50             | BK    | 9519671580 |
   | 333N0003 | IPT        | CPL           | 1.50  | 1.50             | BK    | 9519671581 |
   | 333N0004 | IPT        | CPL           | 1.50  | 1.50             | BK    | 9519671582 |
   | 444N0001 | MPL        | MPL           | 0.10  | 0.10             | BK    | 9519671580 |
  And the following overdue notification weekdays
   | branchCode | weekDays      |
   |            | 1,2,3,4,5,6,7 |
  And the following system preferences
   | systemPreference            | value             |
   | PrintProviderImplementation | PrintProviderEnfo |



 Scenario: Fail sending.
  Given there are no previous overdue notifications
  And there are no previous issues
  And a set of overdue Issues, checked out from the Items' current holdingbranch
   | cardnumber | barcode  | daysOverdue |
   | 333A0002   | 444N0001 | 6           |
  #Default circulation rules typically incur the rental fine
  And there are no previous fines
  When I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber | barcode  | branch   | lettercode | letternumber | status   | transport_type |
   | 333A0002   | 444N0001 | MPL      | ODUEF      | 1            | failed   | print          |
  And I have the following message queue notices
   | cardnumber | lettercode | status   | transport_type | contentRegexp                         |
   | 333A0002   | ODUEF      | failed   | print          | EPL failing\n20333A0002\n31I wish\n\n Barcode: 444N0001 (.+?) |
  And the following fines are encumbered on naughty borrowers
   | cardnumber | fine |
   | 333A0002   | none |



 Scenario: Send only printable overdue notices.
  Given there are no previous overdue notifications
  And there are no previous issues
  And a set of overdue Issues, checked out from the Items' current holdingbranch
   | cardnumber | barcode  | daysOverdue |
   | 111A0001   | 111N0001 | 5           |
   | 222A0002   | 222N0001 | 5           |
   | 222A0002   | 222N0002 | 5           |
   | 333A0001   | 333N0001 | -1          |
   | 333A0001   | 333N0002 | 3           |
   | 333A0001   | 333N0003 | 7           |
   | 333A0001   | 333N0004 | 12          |
  #Default circulation rules typically incur the rental fine
  And there are no previous fines
  When I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber | barcode  | branch   | lettercode | letternumber | status   | transport_type |
   | 111A0001   | 111N0001 | IPT      | ODUE1      | 1            | sent     | print          |
   | 222A0002   | 222N0001 | CPL      | ODUE1      | 1            | sent     | print          |
   | 222A0002   | 222N0002 | IPT      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0003 | CPL      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0004 | CPL      | ODUE1      | 1            | sent     | print          |
  And I have the following message queue notices
   | cardnumber | lettercode | status   | transport_type | contentRegexp                         |
   | 111A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20111A0001\n31I wish\n 1Barcode: 111N0001 (.+?) |
   | 222A0002   | ODUE1      | sent     | print          | EPL 1st. letter\n20222A0002\n31How I\n 1Barcode: 222N0001 (.+?)\n31Did I\n 1Barcode: 222N0002 (.+?) |
   | 333A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20333A0001\n31How I\n 1Barcode: 333N0003 (.+?)\n31Did I\n 1Barcode: 333N0004 (.+?) |
  And the following fines are encumbered on naughty borrowers
   | cardnumber | fine |
   | 111A0001   | 1.0  |
   | 222A0002   | 1.2  |
   | 333A0001   | 1.1  |
  When I fast-forward '5' 'days'
  And I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber | barcode  | branch   | lettercode | letternumber | status   | transport_type |
   | 111A0001   | 111N0001 | IPT      | ODUE1      | 1            | sent     | print          |
   | 222A0002   | 222N0001 | CPL      | ODUE1      | 1            | sent     | print          |
   | 222A0002   | 222N0002 | IPT      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0002 | CPL      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0003 | CPL      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0004 | CPL      | ODUE1      | 1            | sent     | print          |
   | 111A0001   | 111N0001 | IPT      | ODUE2      | 2            | sent     | print          |
   | 222A0002   | 222N0001 | CPL      | ODUE2      | 2            | sent     | print          |
   | 222A0002   | 222N0002 | IPT      | ODUE2      | 2            | sent     | print          |
   | 333A0001   | 333N0003 | CPL      | ODUE2      | 2            | sent     | print          |
   | 333A0001   | 333N0004 | CPL      | ODUE2      | 2            | sent     | print          |
  And I have the following message queue notices
   | cardnumber | lettercode | status   | transport_type | contentRegexp                         |
   | 111A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20111A0001\n31I wish\n 1Barcode: 111N0001 (.+?) |
   | 222A0002   | ODUE1      | sent     | print          | EPL 1st. letter\n20222A0002\n31How I\n 1Barcode: 222N0001 (.+?)\n31Did I\n 1Barcode: 222N0002 (.+?) |
   | 333A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20333A0001\n31I wish\n 1Barcode: 333N0002 (.+?) |
   | 333A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20333A0001\n31How I\n 1Barcode: 333N0003 (.+?)\n31Did I\n 1Barcode: 333N0004 (.+?) |
   | 111A0001   | ODUE2      | sent     | print          | EPL 2nd. letter\n20111A0001\n31I wish\n 1Barcode: 111N0001 (.+?) |
   | 222A0002   | ODUE2      | sent     | print          | EPL 2nd. letter\n20222A0002\n31How I\n 1Barcode: 222N0001 (.+?)\n31Did I\n 1Barcode: 222N0002 (.+?) |
   | 333A0001   | ODUE2      | sent     | print          | EPL 2nd. letter\n20333A0001\n31How I\n 1Barcode: 333N0003 (.+?)\n31Did I\n 1Barcode: 333N0004 (.+?) |
  And the following fines are encumbered on naughty borrowers
   | cardnumber | fine |
   | 111A0001   | 1.0  |
   | 222A0002   | 1.2  |
   | 333A0001   | 1.1  |
   | 333A0001   | 1.1  |
   | 111A0001   | 2.0  |
   | 222A0002   | 2.2  |
   | 333A0001   | 2.1  |
  When I fast-forward '5' 'days'
  And I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber | barcode  | branch   | lettercode | letternumber | status   | transport_type |
   | 111A0001   | 111N0001 | IPT      | ODUE1      | 1            | sent     | print          |
   | 222A0002   | 222N0001 | CPL      | ODUE1      | 1            | sent     | print          |
   | 222A0002   | 222N0002 | IPT      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0001 | IPT      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0002 | CPL      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0003 | CPL      | ODUE1      | 1            | sent     | print          |
   | 333A0001   | 333N0004 | CPL      | ODUE1      | 1            | sent     | print          |
   | 111A0001   | 111N0001 | IPT      | ODUE2      | 2            | sent     | print          |
   | 222A0002   | 222N0001 | CPL      | ODUE2      | 2            | sent     | print          |
   | 222A0002   | 222N0002 | IPT      | ODUE2      | 2            | sent     | print          |
   | 333A0001   | 333N0002 | CPL      | ODUE2      | 2            | sent     | print          |
   | 333A0001   | 333N0003 | CPL      | ODUE2      | 2            | sent     | print          |
   | 333A0001   | 333N0004 | CPL      | ODUE2      | 2            | sent     | print          |
   | 111A0001   | 111N0001 | IPT      | ODUE3      | 3            | sent     | print          |
   | 222A0002   | 222N0001 | CPL      | ODUE3      | 3            | sent     | print          |
   | 222A0002   | 222N0002 | IPT      | ODUE3      | 3            | sent     | print          |
   | 333A0001   | 333N0003 | CPL      | ODUE3      | 3            | sent     | print          |
   | 333A0001   | 333N0004 | CPL      | ODUE3      | 3            | sent     | print          |
  And I have the following message queue notices
   | cardnumber | lettercode | status   | transport_type | contentRegexp                         |
   | 111A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20111A0001\n31I wish\n 1Barcode: 111N0001 (.+?) |
   | 222A0002   | ODUE1      | sent     | print          | EPL 1st. letter\n20222A0002\n31How I\n 1Barcode: 222N0001 (.+?)\n31Did I\n 1Barcode: 222N0002 (.+?) |
   | 333A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20333A0001\n31Did I\n 1Barcode: 333N0001 (.+?) |
   | 333A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20333A0001\n31I wish\n 1Barcode: 333N0002 (.+?) |
   | 333A0001   | ODUE1      | sent     | print          | EPL 1st. letter\n20333A0001\n31How I\n 1Barcode: 333N0003 (.+?)\n31Did I\n 1Barcode: 333N0004 (.+?) |
   | 111A0001   | ODUE2      | sent     | print          | EPL 2nd. letter\n20111A0001\n31I wish\n 1Barcode: 111N0001 (.+?) |
   | 222A0002   | ODUE2      | sent     | print          | EPL 2nd. letter\n20222A0002\n31How I\n 1Barcode: 222N0001 (.+?)\n31Did I\n 1Barcode: 222N0002 (.+?) |
   | 333A0001   | ODUE2      | sent     | print          | EPL 2nd. letter\n20333A0001\n31I wish\n 1Barcode: 333N0002 (.+?) |
   | 333A0001   | ODUE2      | sent     | print          | EPL 2nd. letter\n20333A0001\n31How I\n 1Barcode: 333N0003 (.+?)\n31Did I\n 1Barcode: 333N0004 (.+?) |
   | 111A0001   | ODUE3      | sent     | print          | EPL 3rd. letter\n20111A0001\n31I wish\n 1Barcode: 111N0001 (.+?) |
   | 222A0002   | ODUE3      | sent     | print          | EPL 3rd. letter\n20222A0002\n31How I\n 1Barcode: 222N0001 (.+?)\n31Did I\n 1Barcode: 222N0002 (.+?) |
   | 333A0001   | ODUE3      | sent     | print          | EPL 3rd. letter\n20333A0001\n31How I\n 1Barcode: 333N0003 (.+?)\n31Did I\n 1Barcode: 333N0004 (.+?) |
  And the following fines are encumbered on naughty borrowers
   | cardnumber | fine |
   | 111A0001   | 1.0  |
   | 222A0002   | 1.2  |
   | 333A0001   | 1.1  |
   | 333A0001   | 1.1  |
   | 333A0001   | 1.1  |
   | 111A0001   | 2.0  |
   | 222A0002   | 2.2  |
   | 333A0001   | 2.1  |
   | 333A0001   | 2.1  |
   | 111A0001   | 3.0  |
   | 222A0002   | 3.2  |
   | 333A0001   | 3.1  |
  And the following borrowers are debarred
   | cardnumber |
   | 111A0001   |
   | 222A0002   |
   | 333A0001   |



 Scenario: Tear down any database additions from this feature
   When all scenarios are executed, tear down database changes.
