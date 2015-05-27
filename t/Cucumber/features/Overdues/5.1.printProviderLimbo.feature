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
@overdues
Feature: PrintProviderLimbo is a mock implementation which doesn't actually send anything.
  We still need to test it. These tests are a good basis for other PrintProviderInterface
  implementations.
  By Default we only collect fines for print notifications, but place a debarment for any
  message transport type.
  Also PrintProviderLimbo only sends print-notices.
  That's why no other "message transport type" -notifications are enqueued beyond the first letter,
  since there is no mechanism in this test suite to send them.
  They would normally get processed by the process_message_queue-cronjob.



 Scenario: Set up feature context
  Given the Koha-context, we can proceed with other scenarios.
   | firstName  | surname   | branchCode | branchName | userFlags | userEmail          | branchPrinter |
   | Olli-Antti | Kivilahti | CPL        | CeePeeLib  | 0         | helpme@example.com |               |
  And a set of overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   |            | S                | 1            | print, sms, email     | 5     | ODUE1      | 0        | 1.0  |
   |            | S                | 2            | print, sms, email     | 10    | ODUE2      | 0        | 2.0  |
   |            | S                | 3            | print, sms, email     | 15    | ODUE3      | 1        | 3.0  |
   | CPL        | S                | 1            | sms                   | 5     | ODUE1      | 1        | 1.5  |
   | CPL        | S                | 2            | sms                   | 10    | ODUE2      | 1        | 2.5  |
   | CPL        | S                | 3            | sms                   | 15    | ODUE3      | 1        | 3.5  |
  And a set of letter templates
   | module      | code  | branchcode | name    | is_html | title  | message_transport_types | content                                 |
   | circulation | ODUE1 |            | Notice1 |         | Title1 | print, email, sms       | <<biblio.author>> - <<biblio.title>>, <item>Barcode: <<items.barcode>>, <<issues.date_due>>, <<borrowers.cardnumber>></item> |
   | circulation | ODUE2 |            | Notice2 |         | Title2 | print, email, sms       | <<biblio.author>> - <<biblio.title>>, <item>Barcode: <<items.barcode>>, <<issues.date_due>>, <<borrowers.cardnumber>></item> |
   | circulation | ODUE3 |            | Notice3 |         | Title3 | print, email, sms       | <<biblio.author>> - <<biblio.title>>, <item>Barcode: <<items.barcode>>, <<issues.date_due>>, <<borrowers.cardnumber>></item> |
  And a set of Borrowers
   | cardnumber  | branchcode | categorycode | surname | firstname | address | guarantorbarcode | dateofbirth |
   | 167Azel0001 | CPL        | S            | Costly  | Colt      | Strt 11 |                  | 1985-10-10  |
   | 267Azel0002 | FFL        | S            | Costly  | Caleb     | Strt 11 | 167Azel0001      | 2005-12-12  |
  And a set of Biblios
   | biblio.title             | biblio.author  | biblio.copyrightdate | biblioitems.isbn | biblioitems.itemtype |
   | I wish I met your mother | Pertti Kurikka | 1960                 | 9519671580       | BK                   |
  And a set of Items
   | barcode     | homebranch | holdingbranch | price | replacementprice | itype | biblioisbn |
   | 167Nabe0001 | CPL        | IPT           | 0.50  | 0.50             | BK    | 9519671580 |
   | 267Nabe0002 | FFL        | CPL           | 1.50  | 1.50             | BK    | 9519671580 |
  And the following overdue notification weekdays
   | branchCode | weekDays      |
   |            | 1,2,3,4,5,6,7 |
  And the following system preferences
   | systemPreference            | value              |
   | PrintProviderImplementation | PrintProviderLimbo |



 Scenario: Send only printable overdue notices.
  Given there are no previous overdue notifications
  And there are no previous issues
  And a set of overdue Issues, checked out from the Items' current holdingbranch
   | cardnumber  | barcode     | daysOverdue |
   | 167Azel0001 | 167Nabe0001 | 5           |
   | 267Azel0002 | 267Nabe0002 | 5           |
  #These pesky circulation rules typically incur the rental fine, which is disturbing.
  And there are no previous fines
  When I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | sent     | print          |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | pending  | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | pending  | email          |
   | 267Azel0002 | 267Nabe0002 | CPL      | ODUE1      | 1            | pending  | sms            |
  And I have the following message queue notices
   | cardnumber  | lettercode | status   | transport_type | contentRegexp                         |
   | 167Azel0001 | ODUE1      | sent     | print          | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .+?, 167Azel0001 |
   | 167Azel0001 | ODUE1      | pending  | sms            | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .+?, 167Azel0001 |
   | 167Azel0001 | ODUE1      | pending  | email          | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .+?, 167Azel0001 |
   | 267Azel0002 | ODUE1      | pending  | sms            | Pertti Kurikka - I wish I met your mother, Barcode: 267Nabe0002, .+?, 267Azel0002 |
  And the following fines are encumbered on naughty borrowers
   | cardnumber  | fine |
   | 167Azel0001 | 1.0  |
  And the following borrowers are debarred
   | cardnumber  |
   | 267Azel0002 |
  When I fast-forward '5' 'days'
  And I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | sent     | print          |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | pending  | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | pending  | email          |
   | 267Azel0002 | 267Nabe0002 | CPL      | ODUE1      | 1            | pending  | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE2      | 2            | sent     | print          |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE2      | 2            | pending  | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE2      | 2            | pending  | email          |
   | 267Azel0002 | 267Nabe0002 | CPL      | ODUE2      | 2            | not_odue | sms            |
  And the following fines are encumbered on naughty borrowers
   | cardnumber  | fine |
   | 167Azel0001 | 1.0  |
   | 167Azel0001 | 2.0  |
  When I fast-forward '5' 'days'
  And I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | sent     | print          |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | pending  | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE1      | 1            | pending  | email          |
   | 267Azel0002 | 267Nabe0002 | CPL      | ODUE1      | 1            | pending  | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE2      | 2            | sent     | print          |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE2      | 2            | pending  | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE2      | 2            | pending  | email          |
   | 267Azel0002 | 267Nabe0002 | CPL      | ODUE2      | 2            | not_odue | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE3      | 3            | sent     | print          |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE3      | 3            | pending  | sms            |
   | 167Azel0001 | 167Nabe0001 | IPT      | ODUE3      | 3            | pending  | email          |
   | 267Azel0002 | 267Nabe0002 | CPL      | ODUE3      | 3            | not_odue | sms            |
  And I have the following message queue notices
   | cardnumber  | lettercode | status   | transport_type | contentRegexp                         |
   | 167Azel0001 | ODUE1      | sent     | print          | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
   | 167Azel0001 | ODUE1      | pending  | sms            | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
   | 167Azel0001 | ODUE1      | pending  | email          | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
   | 267Azel0002 | ODUE1      | pending  | sms            | Pertti Kurikka - I wish I met your mother, Barcode: 267Nabe0002, .*?, 267Azel0002 |
   | 167Azel0001 | ODUE2      | sent     | print          | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
   | 167Azel0001 | ODUE2      | pending  | sms            | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
   | 167Azel0001 | ODUE2      | pending  | email          | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
   | 167Azel0001 | ODUE3      | sent     | print          | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
   | 167Azel0001 | ODUE3      | pending  | sms            | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
   | 167Azel0001 | ODUE3      | pending  | email          | Pertti Kurikka - I wish I met your mother, Barcode: 167Nabe0001, .*?, 167Azel0001 |
  And the following fines are encumbered on naughty borrowers
   | cardnumber  | fine |
   | 167Azel0001 | 1.0  |
   | 167Azel0001 | 2.0  |
   | 167Azel0001 | 3.0  |
  And the following borrowers are debarred
   | cardnumber  |
   | 167Azel0001 |
   | 267Azel0002 |



 Scenario: Tear down any database additions from this feature
   When all scenarios are executed, tear down database changes.
