#!/usr/bin/perl
# Outi Billing Version 161124 - Written by Pasi Korkalo 
# Copyright (C)2016 Koha-Suomi Oy
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use utf8;
use strict;
use warnings;
use C4::Context;
use DateTime;
use DBI;

our $dbh=C4::Context->dbh();

sub getbillableitems {
  # Return a list of items that are issued and overdue for at least
  # $overdue amount of days. Filter out billed and non-billable items.
  my $overdue=shift;
  my $branchcategory=shift;
  
  # Define overdue time to exceed for the item to be billed
  my $currentdate=DateTime->from_epoch(epoch => time, time_zone => "local");
  my $overduedays=DateTime::Duration->new(days => $overdue);
  my $duebefore=($currentdate - $overduedays);
  
  my $sth_issues=$dbh->prepare("SELECT itemnumber
                                FROM issues
                                WHERE date_due<?

                                AND itemnumber NOT IN (  
                                  SELECT itemnumber
                                  FROM items
                                  WHERE notforloan=?
                                  OR notforloan=?
                                )

                                AND branchcode IN (
                                  SELECT branchcode
                                  FROM branchrelations
                                  WHERE categorycode=?
                                );");

  $sth_issues->execute($duebefore, nonbillable(), billed(), $branchcategory);

  # Unnecessarily complicated, but how else could this be done?
  my (@items, @billable);
  push @billable, $items[0] while (@items=$sth_issues->fetchrow_array()); 
  return @billable;
}

sub getdue {
  my $sth_due=$dbh->prepare("SELECT date_due
                             FROM issues
                             WHERE itemnumber=?;");
  $sth_due->execute(shift);
  return split('-', substr($sth_due->fetchrow_array(), 0, 10)); 
}

sub getborrowerdata {
  # Get and return borrower information either with itemnumber from
  # issues-table or directly with borrowernumber
  my $by=shift;
  my $borrowernumber;

  if ($by eq 'itemnumber') {
     my $sth_issue=$dbh->prepare("SELECT borrowernumber
                                  FROM issues
                                  WHERE itemnumber=?;");

     $sth_issue->execute(shift);
     $borrowernumber=$sth_issue->fetchrow_array();
  } elsif ($by eq 'borrowernumber') {
     $borrowernumber=shift;
  }

  my $sth_borrower=$dbh->prepare("SELECT borrowernumber, categorycode, guarantorid, relationship, cardnumber, firstname, surname, address, city, zipcode
                                  FROM borrowers
                                  WHERE borrowernumber=?;");

  $sth_borrower->execute($borrowernumber);
  return $sth_borrower->fetchrow_array();
}

sub getssnkey {
  # Get and return borrowers ssn-key
  my $sth_ssn=$dbh->prepare("SELECT attribute
                             FROM borrower_attributes
                             WHERE borrowernumber=?
                             AND code='SSN';");
  $sth_ssn->execute(shift);
  return $sth_ssn->fetchrow_array();
}

sub getitemdata {
  # Get and return item information with itemnumber
  my $sth_item=$dbh->prepare("SELECT biblionumber, barcode, price, itype, holdingbranch
                              FROM items
                              WHERE itemnumber=?;");

  $sth_item->execute(shift);
  my ($biblionumber, $barcode, $price, $itype, $holdingbranch)=$sth_item->fetchrow_array();
  $price="0.00" unless defined $price;

  my $sth_biblio=$dbh->prepare("SELECT author,title
                                FROM biblio
                                WHERE biblionumber=?;");
  
  $sth_biblio->execute($biblionumber);
  my ($author, $title)=$sth_biblio->fetchrow_array();
  $author='' unless defined $author;

  return ($barcode, $price, $itype, $holdingbranch, $author, $title); 
}

sub resolveitemtype {
  # Return real itemtype from itype code
  my $sth_itemtype=$dbh->prepare("SELECT description
                                  FROM itemtypes
                                  WHERE itemtype=?;");
  
  $sth_itemtype->execute(shift);
  return $sth_itemtype->fetchrow_array();
}

sub resolvebranchcode {
  # Return real branchname from branchcode
  my $sth_branchcode=$dbh->prepare("SELECT branchname
                                    FROM branches
                                    WHERE branchcode=?;");
  
  $sth_branchcode->execute(shift);
  return $sth_branchcode->fetchrow_array();
}

sub updatenotforloan {
  # Update notforloan status for billed item if update is set
  if (updateitem()) {
    my $itemnumber=shift;
    my $billed=billed();
  
    $dbh->do("UPDATE items
              SET notforloan=$billed
              WHERE itemnumber=$itemnumber;");
  }
}

1;
