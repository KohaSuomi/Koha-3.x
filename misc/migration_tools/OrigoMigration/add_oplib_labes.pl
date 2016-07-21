#!/usr/bin/perl

use strict;
#use warnings; FIXME - Bug 2505
use  C4::Context;

#
# Will make Bcrypted passwords from imported plain text passwords 
#

my $dbh=C4::Context->dbh;


my $branches=$dbh->prepare("SELECT branchcode FROM branches;");
my $locations=$dbh->prepare("SELECT id, authorised_value FROM authorised_values where category = 'LOC';");

my $oplibs=$dbh->prepare("INSERT INTO oplib_label_mappings (branchcode, location, label) values (?,?,?);");

$branches->execute;
my @allbranches;
$|=1;
while (my ($branchcode)= $branches->fetchrow){
    print "Branchcode : $branchcode\n";
    my $trimmed_branchcode   = substr $branchcode, 4;
    $locations->execute;
	while (my ($id, $authorised_value)= $locations->fetchrow) {
		$oplibs->execute($branchcode, $id, $branchcode.' '.$authorised_value);
	}
}
