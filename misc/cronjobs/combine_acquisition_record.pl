#!/usr/bin/perl

use strict;
use warnings;
use C4::Context;
use POSIX qw/strftime/;
use C4::Reserves qw/_FixPriority/;

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

#Now we are getting current time
my $date = time();

#Now we include all the orders from specified time span

my $days = 1; #This variable is used to determine how old orders we include in this merge
$date = $date - ($days * 24 * 60 * 60);

#Parsing the date in to correct format
my $datestring = strftime "%F", localtime($date);

print "Finding an existing record for records ordered after $datestring.\n";
print "Fetching all the ordered items.\n";
#Here we go through every new item that has been ordered to a specific branch
foreach my $branch(@branches){
	my $orders;

	#Getting every unique item from ordered items
	$query = "SELECT bi.isbn, b.title, bi.issn, bi.ean, aq.biblionumber
			  FROM aqorders aq
			  JOIN items i ON i.biblionumber = aq.biblionumber
			  JOIN biblioitems bi ON bi.biblioitemnumber = i.biblioitemnumber
			  JOIN biblio b ON b.biblionumber = i.biblionumber
			  WHERE aq.entrydate >= ?
			  AND i.homebranch LIKE concat(?, '%')
			  GROUP BY aq.biblionumber
			  ORDER BY aq.biblionumber, b.title, bi.isbn, bi.issn, bi.ean
			  ASC";

	$sth = $dbh->prepare($query);
	$sth->execute($datestring, $branch);

	while(my $row = $sth->fetchrow_arrayref()){
		push @$orders, [@$row];
	}
	#Finding all the ordered items with a specific isbn
	foreach my $order(@$orders){
		print "Looking for an existing item for @$order[4]. \n";

		if(@$order[0]){
			# If the record has isbn number

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
			$sth->execute(@$order[0], $branch, @$order[1]);

		}elsif(@$order[2]){
			# If the record has issn number

			$query = "SELECT min(bi.biblionumber)
					  FROM biblioitems bi
					  JOIN items i ON i.biblioitemnumber = bi.biblioitemnumber
					  JOIN biblio b ON b.biblionumber = i.biblionumber
					  WHERE bi.issn = ?
					  AND i.homebranch LIKE concat(?, '%')
					  AND b.title = ?";

			$sth = $dbh->prepare($query);
			$sth->execute(@$order[2], $branch, @$order[1]);

		}elsif(@$order[3]){
			# If the record has no isbn nor issn

			$query = "SELECT min(bi.biblionumber)
					  FROM biblioitems bi
					  JOIN items i ON i.biblioitemnumber = bi.biblioitemnumber
					  JOIN biblio b ON b.biblionumber = i.biblionumber
					  WHERE bi.ean = ?
					  AND i.homebranch LIKE concat(?, '%')
					  AND b.title = ?";

			$sth = $dbh->prepare($query);
			$sth->execute(@$order[3], $branch, @$order[1]);
		}else{
			# This happens if the record doesn't have isbn, issn or author. I doubt that this really happens
			# but just in case we have to skip to the next record (It's too unreliable to use title only to match records)
			print "Existing item not found\n";
			next;
		}

		my $minbiblionumber = $sth->fetchrow_arrayref;

		#And now the last step is to update the smallest biblionumber to items and aqorders tables
		#and remove the now useless items from biblio and biblioitems tables
		next unless @$minbiblionumber[0];
		if(@$minbiblionumber[0] ne @$order[4]){
			print "Merging biblio record @$order[4] with @$minbiblionumber\n";

			#Updating items table
			$query = "UPDATE items
					  SET biblionumber = ?, biblioitemnumber = ?
					  WHERE biblionumber = ?
					  AND homebranch LIKE concat(?, '%')";

			$sth = $dbh->prepare($query);
			$sth->execute(@$minbiblionumber[0], @$minbiblionumber[0], @$order[4], $branch);

			#Updating aqorders table
			$query = "UPDATE aqorders
					  SET biblionumber = ?
					  WHERE biblionumber = ?";

			$sth = $dbh->prepare($query);
			$sth->execute(@$minbiblionumber[0], @$order[4]);

			print "Merging reserves from @$order[4] with @$minbiblionumber\n";

			#Updating reserves table
			$query = "UPDATE reserves
					  SET biblionumber = ?
					  WHERE biblionumber = ?";

			$sth = $dbh->prepare($query);
			$sth->execute(@$minbiblionumber[0], @$order[4]);

			print "Fixing priority for patrons\n";

			_FixPriority({ biblionumber => @$minbiblionumber[0] });

			#Deleting unnecessary item from biblioitems table
			$query = "DELETE FROM biblioitems
					  WHERE biblionumber = ?";

			$sth = $dbh->prepare($query);
			$sth->execute(@$order[4]);

			#Deleting unnecessary item from biblio table
			$query = "DELETE FROM biblio
					  WHERE biblionumber = ?";

			$sth = $dbh->prepare($query);
			$sth->execute(@$order[4]);
		}else{
			print "Existing item not found\n";
		}
	}#foreach my $order
}#foreach my $branch