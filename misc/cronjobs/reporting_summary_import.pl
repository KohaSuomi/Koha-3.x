#!/usr/bin/perl

use warnings;
use strict;

use C4::Context;
use Data::Dumper;
use Koha::Reporting::Import::Loans;
use Koha::Reporting::Import::FinesOverdue;
use Koha::Reporting::Import::Borrowers::New;
use Koha::Reporting::Import::Borrowers::Deleted;
use Koha::Reporting::Import::Acquisitions;
use Koha::Reporting::Import::Items;
use Koha::Reporting::Import::DeletedItems;
use Koha::Reporting::Import::UpdateItems;


sub changeWaitTimeOut{
    my $dbh = C4::Context->dbh;
    my $stmnt = $dbh->prepare('set wait_timeout = 49');
    $stmnt->execute();
}

changeWaitTimeOut();

print "Starting imports\n";
my $importFinesOverdue = new Koha::Reporting::Import::FinesOverdue; 
my $importLoans = new Koha::Reporting::Import::Loans;
my $importBorrowersNew = new Koha::Reporting::Import::Borrowers::New;
my $importBorrowersDeleted = new Koha::Reporting::Import::Borrowers::Deleted;
my $importAcquisitions = new Koha::Reporting::Import::Acquisitions;
my $importItems = new Koha::Reporting::Import::Items;
my $importDeletedItems = new Koha::Reporting::Import::DeletedItems;
my $importUpdateItems = new Koha::Reporting::Import::UpdateItems;


#$importUpdateItems->truncateUpdateTable();

print "Fines Overdue\n";
$importFinesOverdue->importDatas();
print "Loans\n";
$importLoans->massImport();
print "Borrowers New\n";
$importBorrowersNew->massImport();
print "Borrowers Deleted\n";
$importBorrowersDeleted->massImport();
print "Acquisitions\n";
$importAcquisitions->massImport();
print "Items\n";
$importItems->massImport();
print "Deleted Items\n";
$importDeletedItems->massImport();

print "Update Items\n";
#$importUpdateItems->massImport();

print "Imports Done."








