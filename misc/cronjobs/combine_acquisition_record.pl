#!/usr/bin/perl

use strict;
use warnings;
use C4::Context;
use POSIX qw/strftime/;

#Preparing variables
my @branches;
my $currentbranch = '';

#Let's start by getting all the branchcodes
my $dbh = C4::Context->dbh;
my $query = "SELECT * FROM branches";
my $sth = $dbh->prepare($query);

$sth->execute();

#Adding branchcodes to the @branches list
while (my $branch = $sth->fetchrow_hashref){
	#Getting the first 3 letters from branchcode to identify the city
	#where library is located

	my $prefix = substr($branch->{'branchcode'}, 0, 4);

	#Leaving the duplicates out of the @branches list
	if($currentbranch ne $prefix){
		push @branches, $prefix;	
	}

    $currentbranch = $prefix;
}

#Now we are getting today's orders
my $date = time();

#To make sure we get all new orders we include yesterday's orders as well
$date = $date - (12 * 60 * 60);

#Parsing the date in to correct format
my $datestring = strftime "%F", localtime($date);

#Here we go through every new item that has been ordered to a specific branch
foreach my $branch(@branches){
	my @isbn;

	#Getting every unique isbn numbers from ordered items
	$query = "SELECT bi.isbn, b.title
			  FROM aqorders aq
			  JOIN items i ON i.biblionumber = aq.biblionumber
			  JOIN biblioitems bi ON bi.biblioitemnumber = i.biblioitemnumber
			  JOIN biblio b ON b.biblionumber = i.biblionumber
			  WHERE aq.entrydate >= ?
			  AND i.homebranch LIKE concat(?, '%')
			  GROUP BY bi.isbn";

	$sth = $dbh->prepare($query);
	$sth->execute($datestring, $branch);

	while(my $isbn = $sth->fetchrow_arrayref){
		push @isbn, $isbn;
	}

	#Finding all the ordered items with a specific isbn
	foreach my $isbnnumber(@isbn){
		my @biblionumbers;

		$query = "SELECT aq.biblionumber
			  	  FROM aqorders aq
			      JOIN items i ON i.biblionumber = aq.biblionumber
			      JOIN biblioitems bi ON bi.biblioitemnumber = i.biblioitemnumber
			      JOIN biblio b ON b.biblionumber = i.biblionumber
			      WHERE aq.entrydate >= ?
			      AND i.homebranch LIKE concat(?, '%')
			      AND bi.isbn = ?
			      AND b.title = ?";

		$sth = $dbh->prepare($query);
		$sth->execute($datestring, $branch, @$isbnnumber[0], @$isbnnumber[1]);

		while(my $biblionumber = $sth->fetchrow_hashref){
			push @biblionumbers, $biblionumber->{'biblionumber'};
		}

		#Next step is to find the smallest biblionumber in the current branch that holds
		#the current isbn number
		$query = "SELECT min(bi.biblionumber)
				  FROM biblioitems bi
				  JOIN items i ON i.biblioitemnumber = bi.biblioitemnumber
				  JOIN biblio b ON b.biblionumber = i.biblionumber
				  WHERE bi.isbn = ?
				  AND i.homebranch LIKE concat(?, '%')
				  AND b.title = ?";

		$sth = $dbh->prepare($query);
		$sth->execute(@$isbnnumber[0], $branch, @$isbnnumber[1]);

		my $minbiblionumber = $sth->fetchrow_arrayref;

		#And now the last step is to update the smallest biblionumber to items and aqorders tables
		#and remove the now useless items from biblio and biblioitems tables
		foreach my $biblio(@biblionumbers){
			if(@$minbiblionumber[0] ne $biblio){
				#Updating items table
				$query = "UPDATE items
						  SET biblionumber = ?, biblioitemnumber = ?
						  WHERE biblionumber = ?";

				$sth = $dbh->prepare($query);
				$sth->execute(@$minbiblionumber[0], @$minbiblionumber[0], $biblio);

				#Updating aqorders table
				$query = "UPDATE aqorders
						  SET biblionumber = ?
						  WHERE biblionumber = ?";

				$sth = $dbh->prepare($query);
				$sth->execute(@$minbiblionumber[0], $biblio);

				#Deleting unnecessary item from biblioitems table
				$query = "DELETE FROM biblioitems
						  WHERE biblionumber = ?";

				$sth = $dbh->prepare($query);
				$sth->execute($biblio);

				#Deleting unnecessary item from biblio table
				$query = "DELETE FROM biblio
						  WHERE biblionumber = ?";

				$sth = $dbh->prepare($query);
				$sth->execute($biblio);
			}
		}#foreach my $biblio
	}#foreach my $isbnnumber
}#foreach my $branch