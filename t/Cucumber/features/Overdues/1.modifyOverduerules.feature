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
@overdues
Feature: To configure the Overdues module, we need to be able to CREATE, READ,
 UPDATE and DELETE Overduerules.

 Scenario: Remove all overduerules so we can start testing this feature unhindered
  Given there are no previous overdue notifications
  Then I cannot find any overduerules

 Scenario: Create some default overdue rules.
  Given a set of overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   |            | S                | 1            | print, sms            | 20    | ODUE1      | 0        | 0.0  |
   |            | S                | 2            | print, sms            | 30    | ODUE2      | 0        |      |
   |            | S                | 3            | print, sms            | 40    | ODUE3      | 1        | 5    |
   |            | PT               | 1            | print, sms            | 10    | ODUE1      | 0        | 3    |
   |            | PT               | 2            | print, sms            | 20    | ODUE2      | 0        | 3.3  |
   |            | PT               | 3            | print, sms            | 30    | ODUE3      | 1        | 6.5  |
   | CPL        | PT               | 1            | print                 | 25    | ODUE1      | 0        | 3.3  |
   | CPL        | PT               | 2            | print                 | 45    | ODUE2      | 1        | 5.5  |
   | FTL        | YA               | 1            | print, sms, email     | 15    | ODUE1      | 1        | 1.3  |
   | FTL        | YA               | 2            | print, sms, email     | 30    | ODUE2      | 1        | 2.5  |
   | FTL        | YA               | 3            | print, sms, email     | 45    | ODUE3      | 1        | 1.5  |
   | CCL        | YA               | 1            | print, sms, email     | 45    | ODUE1      | 0        | 1.5  |
   | CCL        | YA               | 2            | print, sms, email     | 90    | ODUE2      | 1        | 2.5  |
   #Last two rows are deleted later.
  Then I should find the rules from the OverdueRulesMap-object.

 Scenario: Update overdue rules defined in the last scenario.
  When I've updated the following overduerules
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine |
   | CCL        | YA               | 1            | print                 | 15    | ODUE1      | 0        | 0.0  |
   | CCL        | YA               | 2            | print,sms             | 45    | ODUE3      | 0        | 5    |
  Then I should find the rules from the OverdueRulesMap-object.

 Scenario: Delete some overdue rules defined in the last scenarios.
  When I've deleted the following overduerules, then I cannot find them.
   | branchCode | borrowerCategory | letterNumber |
   | CCL        | YA               | 1            |
   | CCL        | YA               | 2            |

 Scenario: Create an overduerule with a bad value
  When I try to add overduerules with bad values, I get errors.
   | branchCode | borrowerCategory | letterNumber | messageTransportTypes | delay | letterCode | debarred | fine  | errorCode          |
   | CPL        |                  | 1            | print, sms            | 0     | ODUE1      | 0        | 1.3   | NOBORROWERCATEGORY |
   | FTL        | S                | 2d           | sms                   | 1     | ODUE2      | 1        | 1.3   | BADLETTERNUMBER    |
   | FTL        | S                |              | sms                   | 1     | ODUE2      | 1        | 1.3   | BADLETTERNUMBER    |
   | CPL        | S                | 2            | email                 | f3    | ODUE2      | 1        | 1.3   | BADDELAY           |
   | CPL        | S                | 2            | email                 |       | ODUE2      | 1        | 1.3   | BADDELAY           |
   | FTL        | S                | 3            | print                 | 3     |            | 1        | 1.3   | NOLETTER           |
   | FTL        | S                | 1            | print                 | 3     | ODUE3      | Fäbä     | 1.3   | BADDEBARRED        |
   | FTL        | S                | 1            | print, email          | 3     | ODUE2      | 1        | 2,5   | BADFINE            |
   | FTL        | S                | 1            | print, email          | 3     | ODUE2      | 1        | f2.5  | BADFINE            |
   | FTL        | S                | 3            |                       | 10    | ODUE3      | 0        | 1.3   | NOTRANSPORTTYPES   |

 Scenario: Tear down any database additions from this feature
  When all scenarios are executed, tear down database changes.
