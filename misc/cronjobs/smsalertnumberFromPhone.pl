#!/usr/bin/perl
#-----------------------------------
# Copyright 2008 LibLime
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#-----------------------------------

=head1 NAME

smsalertnumberFromPhone.pl  cron script to enforce borrowers.smsalertnumber if it is different
                            from the primary phone number (borrowers.phone) or the secondary
                            mobile number (borrowers.mobile)

=cut

use strict;
use warnings;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}
use C4::Context;
use Getopt::Long;

my ($help, $confirm, $verbose);

GetOptions(
    'help|h'       => \$help,
    'confirm|c'    => \$confirm,
    'verbose|v'    => \$verbose,
);

my $usage = << 'ENDUSAGE';
smsalertnumberFromPhone.pl  cron script to enforce borrowers.smsalertnumber if it is different
                            from the primary phone number (borrowers.phone) or the secondary
                            mobile number (borrowers.mobile) if they match this regexp /^\+358|^04|^05/

This script takes the following parameters :

    --verbose | v       verbose.

    --confirm | c       confirm.  without this option, the script will not run

    --help | h          This help screen

ENDUSAGE


if ( $help ) {
    print $usage;
}
unless ($confirm) {
    die "ERROR: No confirm option given\n\n$usage";
}

my $dbh = C4::Context->dbh();

#Get the borrowers with not same smsalertnumber
my $sth = $dbh->prepare("SELECT borrowernumber, phone, mobile, smsalertnumber FROM borrowers WHERE smsalertnumber != phone AND smsalertnumber != mobile");
$sth->execute();

#Prepare the UPDATE statement
my $uph = $dbh->prepare("UPDATE borrowers SET smsalertnumber = ? WHERE borrowernumber = ?");

#Make sure the smsalertnumber matches a certain pattern and replace.
my @borrowers = @{ $sth->fetchall_arrayref({}) };
exit 0 unless scalar(@borrowers); #Exit cleanly if there are no smsalertnumbers to fix
print "Borrowernumber : old smsalertnumber becomes phone/mobile \n" if $verbose;
foreach my $borrower ( @borrowers ) {
    if ($borrower->{phone} =~ /^\+358|^04|^05/) { #Simple sanity check. number starts with +358, 04 or 05.
        $uph->execute( $borrower->{phone}, $borrower->{borrowernumber} );
        print "BN " . $borrower->{borrowernumber} . " : SMSALRT " . $borrower->{smsalertnumber} . " => PHONE " . $borrower->{phone} . "\n" if $verbose;
    }
    elsif ($borrower->{mobile} =~ /^\+358|^04|^05/) { #Simple sanity check. number starts with +358, 04 or 05.
        $uph->execute( $borrower->{mobile}, $borrower->{borrowernumber} );
        print "BN " . $borrower->{borrowernumber} . " : SMSALRT " . $borrower->{smsalertnumber} . " => MOBILE " . $borrower->{mobile} . "\n" if $verbose;
    }
    else {
        print "Bad smsalertnumber! BN " . $borrower->{borrowernumber} . " : SMSALRT " . $borrower->{smsalertnumber} . " => PHONE " . $borrower->{phone} . " : MOBILE " . $borrower->{mobile} . "\n";
    }
}
