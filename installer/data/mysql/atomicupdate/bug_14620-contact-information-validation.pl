#! /usr/bin/perl
use strict;
use warnings;
use C4::Context;
my $dbh = C4::Context->dbh;

$dbh->do("INSERT INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('ValidateEmailAddress','0','','Validation of email address on patrons.','YesNo')");   
$dbh->do("INSERT INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('ValidatePhoneNumber','OFF','ipn|fin|new|OFF','Validation of phone number on patrons.','Choice')");
print "Upgrade done (Bug 14620 - KD#61 Contact information validations)\n";
