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
Feature: Finding, sending and fining overdue notifications.
   We need to be able to find overdue issues, generate overdue notifications and
   send the notifications using various message transport types.
   We also must make sure that we don't send overdue notifications too soon if
   overdue notification sending is delayed because of technical issues.
   Also our borrowers must pay a configurable fee for each sent letter and they
   could be debarred for having issues too much overdue.



 Scenario: Set up feature context
  Given the Koha-context, we can proceed with other scenarios.
   | firstName  | surname   | branchCode | branchName | userFlags | userEmail          | branchPrinter |
   | Olli-Antti | Kivilahti | CPL        | CeePeeLib  | 0         | helpme@example.com |               |
  And a set of overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   |            | PT               | 1            | print                 | 5     | ODUE1      | 0        | 1.0  |
   |            | PT               | 2            | print                 | 10    | ODUE2      | 0        | 2.0  |
   |            | PT               | 3            | print                 | 15    | ODUE3      | 1        | 3.0  |
   | FFL        | K                | 1            | print                 | 10    | ODUE1      | 0        | 0.5  |
   | FFL        | K                | 2            | print                 | 20    | ODUE2      | 1        | 1.5  |
   | FFL        | K                | 3            | print                 | 30    | ODUE3      | 1        | 2.5  |
  And a set of letter templates
   | module      | code  | branchcode | name    | is_html | title  | message_transport_types | content                                 |
   | circulation | ODUE1 |            | Notice1 |         | Title1 | print, email, sms       | <<borrowers.cardnumber>>\n<item><<items.barcode>>,</item> |
   | circulation | ODUE2 |            | Notice2 |         | Title2 | print, email, sms       | <<borrowers.cardnumber>>\n<item><<items.barcode>>,</item> |
   | circulation | ODUE3 |            | Notice3 |         | Title3 | print, email, sms       | <<borrowers.cardnumber>>\n<item><<items.barcode>>,</item> |
  And a set of Borrowers
   | cardnumber | branchcode | categorycode | surname | firstname | address | guarantorbarcode | dateofbirth |
   | 11A01      | CPL        | PT           | Costly  | Colt      | Strt 11 |                  | 1985-10-10  |
   | 22A01      | FFL        | K            | Costly  | Caleb     | Strt 11 | 11A01            | 2005-12-12  |
  And a set of Biblios
   | biblio.title             | biblio.author  | biblio.copyrightdate | biblioitems.isbn | biblioitems.itemtype |
   | I wish I met your mother | Pertti Kurikka | 1960                 | 9519671580       | BK                   |
   | Me and your mother       | Jaakko Kurikka | 1961                 | 9519671581       | BK                   |
   | How I met your mother    | Martti Kurikka | 1962                 | 9519671582       | VM                   |
  And a set of Items
   | barcode | homebranch | holdingbranch | price | replacementprice | itype | biblioisbn |
   | 11N01   | CPL        | CPL           | 0.50  | 0.50             | BK    | 9519671580 |
   | 22N01   | FFL        | CPL           | 1.50  | 1.50             | BK    | 9519671580 |
   | 11N02   | CPL        | CPL           | 2.50  | 2.50             | BK    | 9519671581 |
   | 11N03   | CPL        | FFL           | 3.50  | 3.50             | BK    | 9519671581 |
   | 11N04   | CPL        | FFL           | 4.50  | 4.50             | VM    | 9519671582 |
   | 22N02   | FFL        | FFL           | 5.50  | 5.50             | VM    | 9519671582 |
   | 22N03   | FFL        | FFL           | 6.50  | 6.50             | BK    | 9519671580 |
   | 22N04   | FFL        | FFL           | 7.50  | 7.50             | BK    | 9519671580 |
   | 11N05   | CPL        | CPL           | 8.50  | 8.50             | BK    | 9519671582 |
   | 22N05   | FFL        | CPL           | 9.50  | 9.50             | VM    | 9519671582 |
  And the following overdue notification weekdays
   | branchCode | weekDays      |
   |            | 1,2,3,4,5,6,7 |
  And the following system preferences
   | systemPreference            | value              |
   | PrintProviderImplementation | PrintProviderLimbo |



 Scenario: Test long notification message page changes
  Given there are no previous overdue notifications
  And there are no previous issues
  And a set of overdue Issues, checked out from the Items' current holdingbranch
   | cardnumber | barcode | daysOverdue |
   | 11A01      | 11N01   | 5           |
   | 11A01      | 22N01   | 5           |
   | 11A01      | 11N02   | 5           |
   | 11A01      | 11N03   | 5           |
   | 11A01      | 11N04   | 5           |
   | 11A01      | 22N02   | 5           |
   | 11A01      | 22N03   | 5           |
   | 11A01      | 22N04   | 5           |
   | 11A01      | 11N05   | 5           |
  When I gather overdue notifications, with following parameters
   | _repeatPageChange                  | mergeBranches |
   | items => "3", separator => "<BR/>" | 1             |
  And I send overdue notifications
  Then I have the following message queue notices
   | cardnumber | lettercode | status | transport_type | contentRegexp                         |
   | 11A01      | ODUE1      | sent   | print          | 11A01\n..N..,\n..N..,\n..N..,\n<BR/>\n..N..,\n..N..,\n..N..,\n<BR/>\n..N..,\n..N..,\n..N.., |



 Scenario: Simple example of gathering
  Given there are no previous overdue notifications
  And there are no previous issues
  And a set of overdue Issues, checked out from the Items' current holdingbranch
   | cardnumber  | barcode     | daysOverdue |
   | 11A01 | 11N01 | 3           |
  When I gather overdue notifications, merging results from all branches
  And I send overdue notifications
    Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | not_odue | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | not_odue | print          |
  When I fast-forward '5' 'days'
  And I gather overdue notifications, merging results from all branches
  And I send overdue notifications
    Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | not_odue | print          |
  When I fast-forward '5' 'days'
  And I gather overdue notifications, merging results from all branches
  And I send overdue notifications
    Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | not_odue | print          |
  When I fast-forward '5' 'days'
  And I gather overdue notifications, merging results from all branches
  And I send overdue notifications
    Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | sent     | print          |



 Scenario: Gather and send overdue notifications for Items that are never checked-in.
  #We queue letters and forget to send them, then we fix issues and send them again.
  #Time goes on and we queue new notifications without getting the Items back until
  #we run out of different letternumbers.
  #We have two borrowers, a Patron and a Kid, each having different overdue rules.
  #The Kid can only be notified from FFL, even if the Kid has an overdue from CPL, because
  #CPL and default rules doesn't have a overdue rule for Kids. (no_rule)
  Given there are no previous overdue notifications
  And there are no previous issues
  And a set of overdue Issues, checked out from the Items' current holdingbranch
   | cardnumber  | barcode     | daysOverdue |
   | 11A01 | 11N01 | 4           |
   | 11A01 | 22N01 | 5           |
   | 11A01 | 11N02 | 6           |
   | 11A01 | 11N04 | 20          |
   | 22A01 | 22N02 | 3           |
   | 22A01 | 22N03 | 21          |
   | 22A01 | 11N05 | 21          |
  #These pesky circulation rules typically incur the rental fine, which is disturbing.
  And there are no previous fines
  #
  # SubScenario: Find and enqueue first overdue issues.
  When I gather overdue notifications, merging results from all branches
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | not_odue | print          |
   | 11A01 | 22N01 | CPL      | ODUE1      | 1            | pending  | print          |
   | 11A01 | 11N02 | CPL      | ODUE1      | 1            | pending  | print          |
   | 11A01 | 11N04 | FFL      | ODUE1      | 1            | pending  | print          |
   | 22A01 | 22N02 | FFL      | ODUE1      | 1            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE1      | 1            | pending  | print          |
   | 22A01 | 11N05 | CPL      | ODUE1      | 1            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 22N01 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 11N02 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 11N04 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 22N02 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE2      | 2            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 22N01 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 11N02 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 11N04 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N02 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE3      | 3            | no_rule  | print          |
  And I have the following message queue notices
   | cardnumber  | lettercode | status   | transport_type | containedBarcodes                   |
   | 11A01 | ODUE1      | pending  | print          | 22N01,11N02,11N04 |
   | 22A01 | ODUE1      | pending  | print          | 22N03                         |
  #
  # SubScenario: Fast-forward 5 days. Find and enqueue second overdue issues without
  # sending existing ones. New overdue notifications are not generated unless the
  # previous ones have been sent, and a minimum amount of time has passed.
  When I fast-forward '5' 'days'
  When I gather overdue notifications, merging results from all branches
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | pending  | print          |
   | 11A01 | 22N01 | CPL      | ODUE1      | 1            | pending  | print          |
   | 11A01 | 11N02 | CPL      | ODUE1      | 1            | pending  | print          |
   | 11A01 | 11N04 | FFL      | ODUE1      | 1            | pending  | print          |
   | 22A01 | 22N02 | FFL      | ODUE1      | 1            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE1      | 1            | pending  | print          |
   | 22A01 | 11N05 | CPL      | ODUE1      | 1            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 22N01 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 11N02 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 11N04 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 22N02 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE2      | 2            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 22N01 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 11N02 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 11N04 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N02 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE3      | 3            | no_rule  | print          |
  #
  #SubScenario: Send and fine overdue notifications.
  When I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE1      | 1            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 11N05 | CPL      | ODUE1      | 1            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 22N01 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 11N02 | CPL      | ODUE2      | 2            | not_odue | print          |
   | 11A01 | 11N04 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 22N02 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE2      | 2            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 22N01 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 11N02 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 11N04 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N02 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE3      | 3            | no_rule  | print          |
  And the following fines are encumbered on naughty borrowers
   | cardnumber  | fine |
   | 11A01 | 1.0  |
   | 22A01 | 0.5  |
  #
  #SubScenario: Fast-forward 5 days. Find and enqueue second overdue issues having
  #sent previous overdue notifications.
  When I fast-forward '5' 'days'
  When I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 22N03 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 11N05 | CPL      | ODUE1      | 1            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE2      | 2            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE2      | 2            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 22N01 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 11N02 | CPL      | ODUE3      | 3            | not_odue | print          |
   | 11A01 | 11N04 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N02 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE3      | 3            | no_rule  | print          |
  And the following fines are encumbered on naughty borrowers
   | cardnumber  | fine |
   | 11A01 | 1.0  |
   | 11A01 | 2.0  |
   | 22A01 | 0.5  |
   | 22A01 | 0.5  |
  #
  #SubScenario: Fast-forward 5 days. Find and enqueue third overdue issues having
  #sent previous overdue notifications.
  When I fast-forward '5' 'days'
  When I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 22N03 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 11N05 | CPL      | ODUE1      | 1            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE2      | 2            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE2      | 2            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE2      | 2            | sent     | print          |
   | 22A01 | 11N05 | CPL      | ODUE2      | 2            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE3      | 3            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE3      | 3            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE3      | 3            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE3      | 3            | no_rule  | print          |
  And the following fines are encumbered on naughty borrowers
   | cardnumber  | fine |
   | 11A01 | 1.0  |
   | 11A01 | 2.0  |
   | 11A01 | 3.0  |
   | 22A01 | 0.5  |
   | 22A01 | 0.5  |
   | 22A01 | 1.5  |
  And the following borrowers are debarred
   | cardnumber  | type     |
   | 11A01 | OVERDUES |
   | 22A01 | OVERDUES |
  #
  #SubScenario: Fast-forward 10 days. Find and enqueue third overdue issues for
  #the Kid. Observe how he at once gets two letters as separate letters and one
  #fine for each of them. They are delivered to the same address.
  When I fast-forward '5' 'days'
  When I gather overdue notifications, merging results from all branches
  And I send overdue notifications
  Then I have the following enqueued message queue items
   | cardnumber  | barcode     | branch   | lettercode | letternumber | status   | transport_type |
   | 11A01 | 11N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE1      | 1            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 22N03 | FFL      | ODUE1      | 1            | sent     | print          |
   | 22A01 | 11N05 | CPL      | ODUE1      | 1            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE2      | 2            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE2      | 2            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE2      | 2            | sent     | print          |
   | 22A01 | 22N03 | FFL      | ODUE2      | 2            | sent     | print          |
   | 22A01 | 11N05 | CPL      | ODUE2      | 2            | no_rule  | print          |
   | 11A01 | 11N01 | CPL      | ODUE3      | 3            | sent     | print          |
   | 11A01 | 22N01 | CPL      | ODUE3      | 3            | sent     | print          |
   | 11A01 | 11N02 | CPL      | ODUE3      | 3            | sent     | print          |
   | 11A01 | 11N04 | FFL      | ODUE3      | 3            | sent     | print          |
   | 22A01 | 22N02 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 22N03 | FFL      | ODUE3      | 3            | not_odue | print          |
   | 22A01 | 11N05 | CPL      | ODUE3      | 3            | no_rule  | print          |
  And the following fines are encumbered on naughty borrowers
   | cardnumber  | fine |
   | 11A01 | 1.0  |
   | 11A01 | 2.0  |
   | 11A01 | 3.0  |
   | 22A01 | 0.5  |
   | 22A01 | 0.5  |
   | 22A01 | 1.5  |
   | 22A01 | 1.5  |
  And the following borrowers are debarred
   | cardnumber  |
   | 11A01 |
   | 22A01 |



 Scenario: Tear down any database additions from this feature
   When all scenarios are executed, tear down database changes.
