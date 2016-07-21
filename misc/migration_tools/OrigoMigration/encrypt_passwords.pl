#!/usr/bin/perl

use strict;
#use warnings; FIXME - Bug 2505
use  C4::Context;
use Koha::AuthUtils qw(hash_password);
use  C4::Members;

#
# Will make Bcrypted passwords from imported plain text passwords 
#

my $dbh=C4::Context->dbh;


my $borrowers=$dbh->prepare("SELECT borrowernumber, userid, password FROM borrowers WHERE borrowers.password != '' and borrowers.borrowernumber >= 132488");
$borrowers->execute;
$|=1;
while (my ($borrowernumber, $userid,$password)= $borrowers->fetchrow){
	ModMember(borrowernumber => $borrowernumber, password => $password);
    print "Borrower : $borrowernumber, $password\n";
}
