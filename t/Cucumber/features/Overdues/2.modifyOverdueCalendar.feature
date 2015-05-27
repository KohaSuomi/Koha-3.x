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
@overdues
Feature: We need to be able to limit on which days we send overdue notifications.
   To help us with that, we have an Overdues Calendar to tell on which days we can
   gather overdue notifications.
   We need to be able to CRUD the days we want to send overdue notifications.



    #####                                                        #####
    ### SubFeature: Test all Overdues Calendar weekdays-operations ###
    #####                                                        #####



 Scenario: Remove all Overdues Calendar notification gathering days and exceptions.
   Given there are no Overdues Calendar notification gathering weekdays
   And there are no Overdues Calendar notification gathering exception days
   When I get branches available for gathering, pretending that today is 'today'
   Then these branches '' are available for overdue notice gathering

 Scenario: Create some default Calendar weekdays.
   When I've added Overdue notification weekdays '<weekDays>' for branch '<branchCode>'
   Then getting Overdue notification weekdays '<weekDays>' for branch '<branchCode>'
    Examples:
      | branchCode | weekDays  |
      |            | 2,4       |
      | CPL        | 1,2,3,4,5 |
      | FFL        | 1,3,5     |

 Scenario: Display a list of Overdue notification gathering days for the next 3 weeks.
   When I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'FFL', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-01 => OK
      2016-01-04 => OK
      2016-01-06 => OK
      2016-01-08 => OK
      2016-01-11 => OK
      2016-01-13 => OK
      2016-01-15 => OK
      2016-01-18 => OK
      2016-01-20 => OK
      2016-01-22 => OK
      """
      #heredoc bugfix

 Scenario: Update defined Calendar weekdays.
   When I've updated Overdue notification weekdays '3' for branch 'FFL'
   And I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'FFL', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-06 => OK
      2016-01-13 => OK
      2016-01-20 => OK
      """
      #heredoc bugfix

 Scenario: Delete Overdues Calendar weekdays and revert to default weekdays.
   When I've deleted Overdue notification weekdays from branch 'FFL'
   And I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'FFL', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-05 => OK
      2016-01-07 => OK
      2016-01-12 => OK
      2016-01-14 => OK
      2016-01-19 => OK
      2016-01-21 => OK
      """
      #heredoc bugfix

 Scenario: Create an Overdues Calendar weekday with a bad value.
   When I've added Overdue notification weekdays '<weekDays>' for branch '<branchCode>'
   Then I get this error '<errorCode>'
    Examples:
      | branchCode | weekDays  | errorCode     |
      |            | a,4       | BADCHARACTERS |
      | FFL        | 1,2,3,4,5 |               |
      | CPL        | @,.,3,4,5 | BADCHARACTERS |
      | CPL        | 1,3,4,5,  |               |
      | FFL        |           | EMPTYWEEKDAYS |



    #####                                                              #####
    ### SubFeature: Test all Overdues Calendar exception day -operations ###
    #####                                                              #####



 Scenario: Remove all Overdues Calendar notification gathering days and exceptions.
   Given there are no Overdues Calendar notification gathering weekdays
   And there are no Overdues Calendar notification gathering exception days
   When I get branches available for gathering, pretending that today is '2016-01-01'
   Then these branches '' are available for overdue notice gathering

 Scenario: Create some default Calendar weekdays.
   When I've added Overdue notification weekdays '<weekDays>' for branch '<branchCode>'
   Then getting Overdue notification weekdays '<weekDays>' for branch '<branchCode>'
    Examples:
      | branchCode | weekDays  |
      |            | 2,4       |
      | CPL        | 6         |
      | FFL        | 1,3,5     |

 Scenario: Create some default Calendar exception days.
   When I've added Overdue notification exception day '<exceptionDay>' for branch '<branchCode>'
   Then getting Overdue notification exception day '<exceptionDay>' for branch '<branchCode>'
    Examples:
      | branchCode | exceptionDay  |
      |            | 2016-01-01    |
      |            | 2016-01-04    |
      |            | 2016-01-05    |
      |            | 2016-01-06    |
      |            | 2016-01-07    |
      |            | 2016-01-08    |
      |            | 2016-01-09    |
      | CPL        | 2016-01-09    |
      | FFL        | 2016-01-03    |
      | IPT        | 2016-01-07    |
      | IPT        | 2016-01-12    |

 Scenario: Show exception days and how they interact when weekdays are not defined for a branch.
   #If weekdays are defined for a branch, we expect that branch to maintain its own exceptions
   #calendar, thus ignoring all default exceptions.
   #If branch uses the default Overdues Calendar, then it also uses the default exceptions.
   #However a branch can also use exceptions for itself even if it is using the default weekdays.
   #This makes life much easier :)
   When I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'CPL', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-02 => OK
      2016-01-09 => EXCEPTION
      2016-01-16 => OK
      """
   When I've deleted Overdue notification exception day '2016-01-09' for branch 'CPL'
   And I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'CPL', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-02 => OK
      2016-01-09 => OK
      2016-01-16 => OK
      """
   When I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'FFL', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-01 => OK
      2016-01-04 => OK
      2016-01-06 => OK
      2016-01-08 => OK
      2016-01-11 => OK
      2016-01-13 => OK
      2016-01-15 => OK
      2016-01-18 => OK
      2016-01-20 => OK
      2016-01-22 => OK
      """
      #Note that the exception for FFL is not taken into account, because it doesn't overlap with the weekdays.
      #This makes it possible to change the weekdays without reconfiguring all exception days again.
      #This also makes recovering from user errors more easy :)
      #
   When I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'IPT', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-05 => EXCEPTION
      2016-01-07 => EXCEPTION
      2016-01-12 => EXCEPTION
      2016-01-14 => OK
      2016-01-19 => OK
      2016-01-21 => OK
      """
      #IPT is using the default weekdays, but can still override with it's own exceptions
      #
   When I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'PVL', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-05 => EXCEPTION
      2016-01-07 => EXCEPTION
      2016-01-12 => OK
      2016-01-14 => OK
      2016-01-19 => OK
      2016-01-21 => OK
      """
      #PVL is using the default weekdays, with default exceptions
      #
   When I've updated Overdue notification weekdays '1,3,5' for branch ''
   And I display the Overdues Calendar for the next '3' 'weeks' as text for branch 'PVL', pretending that today is '2016-01-01'
   Then I get the following output
      """
      2016-01-01 => EXCEPTION
      2016-01-04 => EXCEPTION
      2016-01-06 => EXCEPTION
      2016-01-08 => EXCEPTION
      2016-01-11 => OK
      2016-01-13 => OK
      2016-01-15 => OK
      2016-01-18 => OK
      2016-01-20 => OK
      2016-01-22 => OK
      """
      #Now we changed the default weekdays, and should get different exception days for PVL
      #

 Scenario: Get branches available for overdue notification gathering for today.

 Scenario: Create Overdues Calendar exception days with bad values.
   When I've added Overdue notification exception day '<exceptionDay>' for branch '<branchCode>'
   Then I get this error '<errorCode>'
    Examples:
      | branchCode | exceptionDay | errorCode     |
      | FFL        | 2000-02-05   |               |
      | CPL        | 201o-01-02   | BADDATE       |
      | CPL        |              | NODATE        |

 Scenario: Create some default Calendar exception days using DateTime.
   #Exception days should be given as DateTime-objects, but for ease of use,
   # especially during testing,
   #the modules automatically convert iso8601 timestamps to DateTime.
   #These tests make sure that using DateTimes works as well.
   When I've added Overdue notification exception day '<exceptionDay>' as DateTime for branch '<branchCode>'
   Then getting Overdue notification exception day '<exceptionDay>' for branch '<branchCode>'
    Examples:
      | branchCode | exceptionDay  |
      |            | 2016-01-08    |
      |            | 2016-01-09    |
      | CPL        | 2016-01-09    |
      | FFL        | 2016-01-03    |
      | IPT        | 2016-01-07    |
      | IPT        | 2016-01-12    |



    #####
    ### SubFeature: Get each branch with permission to gather notices on a given day.
    #####



 Scenario: Remove all Overdues Calendar notification gathering days and exceptions.
   Given there are no Overdues Calendar notification gathering weekdays
   Given there are no Overdues Calendar notification gathering exception days

 Scenario: Create some default Calendar weekdays.
   When I've added Overdue notification weekdays '<weekDays>' for branch '<branchCode>'
    Examples:
      | branchCode | weekDays          |
      |            | 1                 |
      | CPL        | 2,4,6             |
      | FFL        | 3,5               |
      | IPT        | 3,5,7             |
      | PVL        | 2,3,4,5,6,7       |

 Scenario: Create some default Calendar exception days.
   When I've added Overdue notification exception day '<exceptionDay>' for branch '<branchCode>'
    Examples:
      | branchCode | exceptionDay  |
      |            | 2016-01-01    |
      | FFL        | 2016-01-03    |
      | RPL        | 2016-01-04    |
      | CPL        | 2016-01-09    |
      | RPL        | 2016-01-11    |
      | UPL        | 2016-01-11    |
      | IPT        | 2016-01-12    |
      | IPT        | 2016-01-17    |

 Scenario: See if our example branches have the permission to do overdue notification gathering.
   #Testing a common case where only weekDays are needed.
   When I get branches available for gathering, pretending that today is '<today>'
   Then these branches '<branchCodes>' are available for overdue notice gathering
    Examples:
      | today      | branchCodes                     |
      | 2016-01-01 | FFL,IPT,PVL                     |
      | 2016-01-02 | CPL,PVL                         |
      | 2016-01-05 | CPL,PVL                         |
      | 2016-01-08 | FFL,IPT,PVL                     |
      | 2016-01-26 | CPL,PVL                         |
      | 2016-02-02 | CPL,PVL                         |

 Scenario: See if our example branches have the permission to do overdue notification gathering.
   #Testing when a special rules branch, is excluded via an exception day
   When I get branches available for gathering, pretending that today is '<today>'
   Then these branches '<branchCodes>' are available for overdue notice gathering
    Examples:
      | today      | branchCodes                     |
      | 2016-01-03 | IPT,PVL                         |
      | 2016-01-09 | PVL                             |
      | 2016-01-17 | PVL                             |

 Scenario: See if our example branches have the permission to do overdue notification gathering.
   #Testing when a default rules using branch, is excluded via a branch specific
   #exception day
   When I get branches available for gathering, pretending that today is '<today>'
   Then these branches '<branchCodes>' are available for overdue notice gathering
    Examples:
      | today      | branchCodes                     |
      | 2016-01-04 | FPL,FRL,LPL,MPL,SPL,TPL,UPL     |
      | 2016-01-11 | FPL,FRL,LPL,MPL,SPL,TPL         |



    #####       #####
    ### Tear down ###
    #####       #####



 Scenario: Tear down any database additions from this feature
   When all scenarios are executed, tear down database changes.
