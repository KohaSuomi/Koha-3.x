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

sub getdate {
  my ($sec, $min, $hour, $dom, $month, $year, @discard)=localtime;
  undef @discard;
  $year+=1900;
  $month+=1;
  return $sec, $min, $hour, $dom, $month, $year;
}

sub logger {
  my ($sec, $min, $hour, $dom, $month, $year)=getdate();
  print $year . '-' . $month . '-' . $dom . ' ' . $hour . ':' . $min . ':' . $sec . ' ';
  print @_;
  print "\n";
}

sub filename {
  my $branchcategory=shift;
  my $output=output($branchcategory);
  my ($sec, $min, $hour, $dom, $month, $year)=getdate();
  return 'KIKOHA' . $output . $branchcategory . $year . $month . $dom . $hour . $min . $sec . '.dat';
}

sub writefile {
  my $branchcategory=shift;
  my $encoding=encoding($branchcategory);
  my $targetdir=targetdir($branchcategory);
  my $filename=filename($branchcategory);

  # Write it (will probably spit out some encoding warnings)
  open OUTFILE, ">:encoding($encoding)", $targetdir . '/' . $filename or die "Can't open ". $targetdir . "/test-filedata.dat for writing.";
  foreach (@_) {
    print OUTFILE $_;
  }
  close OUTFILE;

  # "Fix" (or rather "neutralise") encoding errors
  if ( $encoding ne 'UTF-8' ) {
    open INFILE, "<:encoding($encoding)", $targetdir . '/' . $filename or die "Can't open ". $targetdir . "/test-filedata.dat for reading.";
    my @FILE=<INFILE>;
    close INFILE;

    open OUTFILE, ">:encoding($encoding)", $targetdir . '/' . $filename or die "Can't open ". $targetdir . "/test-filedata.dat for writing.";
    foreach (@FILE) {
      my $outline=$_;
      $outline=~s/\\x\{....\}/?/g;
      print OUTFILE $outline;
    }
    close OUTFILE;
  }
}

1;
