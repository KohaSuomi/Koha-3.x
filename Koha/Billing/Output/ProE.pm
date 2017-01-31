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

our %bills;
our %guarantee;

sub ProE {
  my $branchcategory=shift;
  my @writefile;
  push @writefile, $branchcategory;
  
  foreach my $borrower (keys %bills) {
    
    my ( $borrowernumber,
         $borrowercategory,
         $guarantorid,
         $relationship,
         $cardnumber,
         $firstname,
         $surname,
         $address,
         $city,
         $zipcode
       ) = getborrowerdata('borrowernumber', $borrower);
    
    $cardnumber='' unless defined $cardnumber;
  
    # We need SSN 
    my $ssn=getssn($borrowernumber);
  
    # ProE Header data
    my $padded_borrowernumber=sprintf ('%011d', $borrowernumber);
    my $blank_line=$padded_borrowernumber . "3\r\n";
    my $header=$padded_borrowernumber;
       $header.=sprintf ('%-63s', 'L10' . $surname . ' ' . $firstname);
       $header.=sprintf ('%-30s', $address);
       $header.=sprintf ('%-232s', $zipcode . $city);
       $header.=sprintf ('%-171s', $padded_borrowernumber);
       $header.=$ssn . "\r\n";
  
    push @writefile, $header;
    
    # Insert bill receiver
    push @writefile, $padded_borrowernumber . '3Laskun saaja: ' . $cardnumber . "\r\n";
    push @writefile, $blank_line;
  
    # Starting texts
    push @writefile, $padded_borrowernumber . "3PALAUTTAMATON AINEISTO:\r\n";
    push @writefile, $blank_line;
    
    # Insert billable items
    for ( 0 .. $#{$bills{$borrower}}) {
      my $itemnumber=$bills{$borrower}[$_];
  
      # Get item data
      my ( $barcode,
           $price,
           $itype,
           $holdingbranch,
           $author,
           $title ) = getitemdata($itemnumber);
      
      # Resolve real itemtype and branch
      my $itemtype=resolveitemtype($itype);
      my $branch=resolvebranchcode($holdingbranch);
     
      # When was the item due
      my ($year, $month, $day)=getdue($itemnumber);
      my $due=$day . '.' . $month . '.' . $year;
  
      $author=$author . ' ' unless $author eq '';
      my $itemline=$barcode . ': ' . $itemtype . ', ' . $due . ', ' . $branch . ', ' . $author . $title;
      
      # First line of text 
      my $mainitemline=sprintf('%-86s', $padded_borrowernumber . '200' . substr($itemline, 0, 62));
      
      # Format price for proe
      $price=~s/\.//;
      $mainitemline.=sprintf('%6s', $price . 'B') . "\r\n";
  
      push @writefile, $mainitemline;
  
      # Second line of text if the itemline was over 62 character (additional lines after the second one
      # will just be skipped, two lines is enough ;P)
      push @writefile, $padded_borrowernumber . '3' . substr($itemline, 62, 124) . "\r\n" if length($itemline) > 62; 
  
      # Add guarantee if not the same as borrower + block patron
      my (@guaranteedata $guaranteeline);
      if (defined $guarantee{$itemnumber}) {
        @guaranteedata=getborrowerdata('borrowernumber', $guarantee{$itemnumber});
        $guaranteeline=$guaranteedata[6] . ' ' $guaranteedata[5] . ' (' . $guaranteedata[4] . ')';
        push @writefile, $padded_borrowernumber . '3LAINAAJA: ' . substr($guaranteeline), 0, 62) . "\r\n";
        debar $branchcategory, $guarantee{$itemnumber}, 'LASKUNUMERO?', $isodate;
      else
        debar $branchcategory, $borrowernumber, 'LASKUNUMERO?', $isodate;
      }
  
      push @writefile, $blank_line;
  
      # Update the billed status (if defined to be updated) 
      updatenotforloan($itemnumber);
    }
    # Finally...
    push @writefile, $padded_borrowernumber . "3LASKUA EI TARVITSE MAKSAA, JOS AINEISTO PALAUTETAAN.\r\n";
    push @writefile, $padded_borrowernumber . "3Veroton vahingonkorvaus.\r\n"
  }

  writefile(@writefile);
  return 1;
}
1;
