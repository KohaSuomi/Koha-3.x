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
Feature: Unit tests

 Scenario: Set up feature context
  Given the Koha-context, we can proceed with other scenarios.
   | firstName  | surname   | branchCode | branchName | userFlags | userEmail          | branchPrinter |
   | Olli-Antti | Kivilahti | CPL        | CeePeeLib  | 0         | helpme@example.com |               |
  And a set of letter templates
   | module      | code  | branchcode | name    | is_html | title  | message_transport_types | content                                 |
   | circulation | ODUE1 |            | Notice1 |         | Title1 | print, email, sms       | <<borrowers.cardnumber>>\n<item><<items.barcode>>,</item> |
   | circulation | ODUE2 |            | Notice2 |         | Title2 | print, email, sms       | <<borrowers.cardnumber>>\n<item><<items.barcode>>,</item> |
   | circulation | ODUE3 |            | Notice3 |         | Title3 | print, email, sms       | <<borrowers.cardnumber>>\n<item><<items.barcode>>,</item> |
  And the following overdue notification weekdays
   | branchCode | weekDays      |
   |            | 1,2,3,4,5,6,7 |
  And the following system preferences
   | systemPreference            | value              |
   | PrintProviderImplementation | PrintProviderLimbo |


 Scenario: getLatestOverdueNotification, both in scalar and list-contexts
 #Test scalar
  Given a set of overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   |            | PT               | 1            | print                 | 5     | ODUE1      | 0        | 1.0  |
   |            | PT               | 2            | print                 | 10    | ODUE2      | 0        | 2.0  |
   | FFL        | K                | 1            | print                 | 10    | ODUE1      | 0        | 0.5  |
   | FFL        | K                | 2            | print                 | 20    | ODUE2      | 1        | 1.5  |
  When I request the last overdue rules in 'scalar'-context
  Then I get the following last overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   | FFL        | K                | 2            | print                 | 20    | ODUE2      | 1        | 1.5  |
  Given there are no previous overduerules
 #Test list
  Given a set of overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   |            | PT               | 1            | print                 | 5     | ODUE1      | 0        | 1.0  |
   |            | PT               | 2            | print                 | 10    | ODUE2      | 0        | 2.0  |
   |            | PT               | 3            | print, sms            | 20    | ODUE3      | 1        | 2.0  |
   | CPL        | K                | 3            | print                 | 20    | ODUE3      | 1        | 1.5  |
   | FFL        | K                | 3            | print, sms, email     | 20    | ODUE3      | 1        | 1.5  |
   | FFL        | K                | 2            | print                 | 15    | ODUE2      | 1        | 1.0  |
   | FFL        | K                | 1            | print                 | 10    | ODUE1      | 1        | 0.5  |
  When I request the last overdue rules in 'list'-context
  Then I get the following last overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   |            | PT               | 3            | print, sms            | 20    | ODUE3      | 1        | 2.0  |
   | CPL        | K                | 3            | print                 | 20    | ODUE3      | 1        | 1.5  |
   | FFL        | K                | 3            | print, sms, email     | 20    | ODUE3      | 1        | 1.5  |

 Scenario: Tear down any database additions from this feature
   When all scenarios are executed, tear down database changes.
