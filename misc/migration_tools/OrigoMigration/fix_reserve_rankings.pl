#!/usr/bin/perl

use strict;
#use warnings; FIXME - Bug 2505
use C4::Context;
use C4::Reserves;
#
# Will fix ranking on reservations
#

my $dbh=C4::Context->dbh;


my $reserves=$dbh->prepare("SELECT reserve_id, biblionumber, reservedate FROM reserves;");
$reserves->execute;
$|=1;
while (my ($reserve_id, $biblionumber, $reservedate )= $reserves->fetchrow){
	my $rank = CalculatePriority($biblionumber, $reservedate);
	my $query = "
		UPDATE reserves SET priority = ?
	 	WHERE reserve_id = ?
	 	";
	my $sth = $dbh->prepare($query);
	$sth->execute( $rank, $reserve_id );

    print "Reserve : $reserve_id \n";
}

print "Fixing rankings next...";

my $fixpriority=$dbh->prepare("SELECT biblionumber FROM reserves;");
$fixpriority->execute;
$|=1;

while (my ($biblionumber)= $fixpriority->fetchrow){

	_FixPriority({ biblionumber => $biblionumber});

    print "Fixing : $biblionumber \n";
}


