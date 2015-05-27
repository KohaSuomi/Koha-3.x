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
#
#This Feature not customer-oriented, because this feature is only used when migrating
#to use this feature. That is a non-customer task.
#
@overdues
Feature: To use the new Overdues module, we need to get the Items out of old
   Messages into the new message_queue_items-table, so we get more information
   regarding notifications sent because of each Item.
   Mainly the time each Item has been sent, and for which letter.

 Scenario: Set up Koha Context
  Given the Koha-context, we can proceed with other scenarios.
   | firstName  | surname   | branchCode | branchName | userFlags | userEmail          | branchPrinter |
   | Olli-Antti | Kivilahti | CPL        | CeePeeLib  | 0         | helpme@example.com |               |

 Scenario: Create message_queue_items from message_queues for overdue letters.
  Given a set of overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode  | debarred | fine |
   |            | PT               | 1            | print, sms            | 10    | ODUE1       | 0        | 1.5  |
   |            | PT               | 2            | print, sms            | 20    | ODUE2       | 0        | 2.5  |
   |            | PT               | 3            | print                 | 30    | ODUE3       | 1        | 3.5  |
  And a set of letter templates
   | module      | code  | branchcode | name    | is_html | title  | message_transport_types | content                                 |
   | circulation | ODUE1 |            | Notice1 |         | Title1 | print, email, sms       | <item>Barcode: <<items.barcode>>, bring it back!</item> |
   | circulation | ODUE2 |            | Notice2 |         | Title2 | print, email, sms       | <item>Barcode: <<items.barcode>></item> |
   | circulation | ODUE3 |            | Notice3 |         | Title3 | print, email, sms       | <item>Barcode: <<items.barcode>>, bring back!</item> |
  And a set of Borrowers
   | cardnumber  | branchcode | categorycode | surname | firstname | address | guarantorbarcode | dateofbirth |
   | 167Azel0001 | CPL        | PT           | Costly  | Colt      | Strt 11 |                  | 1985-10-10  |
   | 167Azel0002 | CPL        | K            | Costly  | Caleb     | Strt 11 | 167Azel0001      | 2005-12-12  |
   | 267Azel0003 | FFL        | S            | Pricy   | Volt      | Road 12 |                  | 1980-10-10  |
  And a set of Biblios
   | biblio.title             | biblio.author  | biblio.copyrightdate | biblioitems.isbn | biblioitems.itemtype |
   | I wish I met your mother | Pertti Kurikka | 1960                 | 9519671580       | BK                   |
   | Me and your mother       | Jaakko Kurikka | 1961                 | 9519671581       | BK                   |
   | How I met your mother    | Martti Kurikka | 1962                 | 9519671582       | VM                   |
  And a set of Items
   | barcode     | homebranch | holdingbranch | price | replacementprice | itype | biblioisbn |
   | 167Nabe0001 | CPL        | CPL           | 0.50  | 0.50             | BK    | 9519671580 |
   | 167Nabe0002 | CPL        | FFL           | 3.50  | 3.50             | BK    | 9519671581 |
   | 167Nabe0003 | CPL        | FFL           | 4.50  | 4.50             | VM    | 9519671582 |
   | 267Nabe0004 | FFL        | FFL           | 5.50  | 5.50             | VM    | 9519671582 |
   | 267Nabe0005 | FFL        | FFL           | 6.50  | 6.50             | BK    | 9519671580 |
   | 267Nabe0006 | FFL        | FFL           | 7.50  | 7.50             | BK    | 9519671580 |
   | 267Nabe0007 | FFL        | CPL           | 8.50  | 8.50             | BK    | 9519671582 |
  And a set of overdue Issues, checked out from the Items' current holdingbranch
   | cardnumber  | barcode     | daysOverdue |
   | 167Azel0001 | 167Nabe0001 | 9           |
   | 167Azel0001 | 167Nabe0002 | 21          |
   | 167Azel0002 | 167Nabe0003 | 9           |
   | 167Azel0002 | 267Nabe0004 | 15          |
   | 167Azel0002 | 267Nabe0005 | 22          |
   | 267Azel0003 | 267Nabe0006 | 8           |
   | 267Azel0003 | 267Nabe0007 | 15          |
  Given a bunch of message_queue-rows using letter code 'ODUE1' and message_transport_type 'email' based on the given Borrowers, Biblios, Items and Issues
  Given a bunch of message_queue-rows using letter code 'ODUE1' and message_transport_type 'print' based on the given Borrowers, Biblios, Items and Issues
  Given a bunch of message_queue-rows using letter code 'ODUE2' and message_transport_type 'print' based on the given Borrowers, Biblios, Items and Issues
  Given a bunch of message_queue-rows using letter code 'ODUE3' and message_transport_type 'sms' based on the given Borrowers, Biblios, Items and Issues
  When I've ran the overdue letters migrator with the Item finding regexp 'Barcode: (.+?)(?:$|\\s|[.,])'
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 167Azel0001 | 167Nabe0001 | CPL      | ODUE1      | 1            | pending  | email          |
   | 167Azel0001 | 167Nabe0002 | FFL      | ODUE1      | 1            | pending  | email          |
   | 167Azel0002 | 167Nabe0003 | FFL      | ODUE1      | 1            | pending  | email          |
   | 167Azel0002 | 267Nabe0004 | FFL      | ODUE1      | 1            | pending  | email          |
   | 167Azel0002 | 267Nabe0005 | FFL      | ODUE1      | 1            | pending  | email          |
   | 267Azel0003 | 267Nabe0006 | FFL      | ODUE1      | 1            | pending  | email          |
   | 267Azel0003 | 267Nabe0007 | CPL      | ODUE1      | 1            | pending  | email          |
   | 167Azel0001 | 167Nabe0001 | CPL      | ODUE1      | 1            | pending  | print          |
   | 167Azel0001 | 167Nabe0002 | FFL      | ODUE1      | 1            | pending  | print          |
   | 167Azel0002 | 167Nabe0003 | FFL      | ODUE1      | 1            | pending  | print          |
   | 167Azel0002 | 267Nabe0004 | FFL      | ODUE1      | 1            | pending  | print          |
   | 167Azel0002 | 267Nabe0005 | FFL      | ODUE1      | 1            | pending  | print          |
   | 267Azel0003 | 267Nabe0006 | FFL      | ODUE1      | 1            | pending  | print          |
   | 267Azel0003 | 267Nabe0007 | CPL      | ODUE1      | 1            | pending  | print          |
   | 167Azel0001 | 167Nabe0001 | CPL      | ODUE2      | 2            | pending  | print          |
   | 167Azel0001 | 167Nabe0002 | FFL      | ODUE2      | 2            | pending  | print          |
   | 167Azel0002 | 167Nabe0003 | FFL      | ODUE2      | 2            | pending  | print          |
   | 167Azel0002 | 267Nabe0004 | FFL      | ODUE2      | 2            | pending  | print          |
   | 167Azel0002 | 267Nabe0005 | FFL      | ODUE2      | 2            | pending  | print          |
   | 267Azel0003 | 267Nabe0006 | FFL      | ODUE2      | 2            | pending  | print          |
   | 267Azel0003 | 267Nabe0007 | CPL      | ODUE2      | 2            | pending  | print          |
   | 167Azel0001 | 167Nabe0001 | CPL      | ODUE3      | 3            | pending  | sms            |
   | 167Azel0001 | 167Nabe0002 | FFL      | ODUE3      | 3            | pending  | sms            |
   | 167Azel0002 | 167Nabe0003 | FFL      | ODUE3      | 3            | pending  | sms            |
   | 167Azel0002 | 267Nabe0004 | FFL      | ODUE3      | 3            | pending  | sms            |
   | 167Azel0002 | 267Nabe0005 | FFL      | ODUE3      | 3            | pending  | sms            |
   | 267Azel0003 | 267Nabe0006 | FFL      | ODUE3      | 3            | pending  | sms            |
   | 267Azel0003 | 267Nabe0007 | CPL      | ODUE3      | 3            | pending  | sms            |

 Scenario: Tear down any database additions from this feature
   When all scenarios are executed, tear down database changes.
