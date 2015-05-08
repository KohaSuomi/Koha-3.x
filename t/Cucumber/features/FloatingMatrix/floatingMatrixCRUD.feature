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
Feature: Floating matrix CRUD
 We must be able to define the Floating matrix rules to use them.

 Scenario: Remove all Floating matrix rules so we can test unhindered.
   Given there are no Floating matrix rules
   Then there are no Floating matrix rules

 Scenario: Create some default Floating matrix rules
   Given a set of Floating matrix rules
    | fromBranch | toBranch | floating    | conditionRules        |
    | CPL        | FFL      | ALWAYS      |                       |
    | CPL        | IPT      | POSSIBLE    |                       |
    | FFL        | CPL      | ALWAYS      |                       |
    | FFL        | IPT      | CONDITIONAL | itype ne BK           |
    | IPT        | FFL      | ALWAYS      |                       |
    | IPT        | CPL      | ALWAYS      |                       |
   Then I should find the rules from the Floating matrix

 Scenario: Delete some Floating matrix rules
  When I've deleted the following Floating matrix rules, then I cannot find them.
    | fromBranch | toBranch |
    | IPT        | FFL      |
    | IPT        | CPL      |

 Scenario: Update some Floating matrix rules
  Given a set of Floating matrix rules
    | fromBranch | toBranch | floating    | conditionRules |
    | CPL        | FFL      | POSSIBLE    |                |
    | CPL        | IPT      | ALWAYS      |                |
    | FFL        | CPL      | CONDITIONAL | itype ne BK    |
    | FFL        | IPT      | CONDITIONAL | ccode eq FLOAT |
   Then I should find the rules from the Floating matrix

 Scenario: Intercept bad Floating matrix rules.
  When I try to add Floating matrix rules with bad values, I get errors.
    | fromBranch | toBranch | floating    | conditionRules         | errorString                                       |
    |            | FFL      | POSSIBLE    |                        | No 'fromBranch'                                   |
    | CPL        |          | ALWAYS      |                        | No 'toBranch'                                     |
    | FFL        | CPL      |             | itype ne BK            | No 'floating'                                     |
    | FFL        | IPT      | CONDOM      | ccode eq FLOAT         | Bad enum                                          |
    | FFL        | CPL      | CONDITIONAL |                        | No 'conditionRules' when floating = 'CONDITIONAL' |
    | FFL        | IPT      | CONDITIONAL | {system('rm -rf /');}; | Not allowed 'conditionRules' characters           |
    | CPL        | FFL      | ALWAYS      | permanent_location ne REF and permanent_location ne CART and permanent_location ne REF and permanent_location ne REF | 'conditionRules' text is too long. |

 Scenario: Tear down any database additions from this feature
  When all scenarios are executed, tear down database changes.

