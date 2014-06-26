#!/usr/bin/perl

# Copyright Anonymous
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warganty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use utf8;


BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use Getopt::Long;
use C4::OPLIB::Claiming;
use POSIX;

binmode STDOUT, ":encoding(UTF-8)";


##Firstly check for new claiming_items from the message_queue -table.


my $arg = {};
$arg->{help} = 0;
$arg->{hostname} = '';
$arg->{verbose} = 0;
$arg->{doClaimletters} = 0;
$arg->{removeStale} = 0;
$arg->{doOverdues} = 0;
GetOptions(
    'h|help|?'          => \$arg->{help},
    'h|hostname=s'      => \$arg->{hostname},
    'c|claimletters'    => \$arg->{doClaimletters},
    'r|removestale'     => \$arg->{removeStale},
    'o|odue'            => \$arg->{doOverdues},
    'v|verbose'         => \$arg->{verbose},
);
my $usage = << 'ENDUSAGE';

REQUIREMENTS:
cpan install OpenOffice::OODoc
cpan install MIME::Lite
letter_types ODUE1 and ODUE2 and ODUECLAIM need to be defined from the letter templates.
Templates can be found from KD-37 and KD-42
Define overdue action here: tools/overduerules.pl ; to use the ODUE1, ODUE2, ODUECLAIM letter templates.


For letter_codes ODUE1 and ODUE2
Finds all pending or failed overdue messages with ODUE1 and ODUE2 letters and sends them.
Creates a $odue1Price or $odue2Price fine for each sent letter to the overdue perpetrator (even a juvenile).

For letter_code ODUECLAIM
Builds all claimletters sorted by the items homebranch and guarantor.
Writes letters to separate .odts by the homebranch.
This is needed by the tools/claim.pl to get the pending claim letter count per branch.

USE CASES:

send_overdue_mail.pl --verbose --removestale --claimletters
    Run daily after library closes to update the claimletters for the claiming module.
    Removes all .odt-files from claimletterOdt-directory, thus cleaning previous days claimletters.
    Creates new claimletters for the claiming module at tools/claim.pl to monitor pending claim requests.

send_overdue_mail.pl --verbose --odue
    Run once a week on tuesday mornings (or whenever you want to send ODUE-letters).
    Sends all ODUE1 and ODUE2 -letters to the print service provider. Adds a notification fee to Patrons.


This script has the following parameters :

    -h --help         this message

    -r --removestale  Remove not-closed claim letters. Meant to clean the claimletterOdt-directory
                      from yesterdays unprocessed claimletters.

    -c --claimletters Generate the claim letters

    -o --odue         Send overdue notifications ODUE1 and ODUE2 via print service provider

    -v --verbose      show verbose information about script internals.
                      Verbose mode prints a letter for each message_queue item processed.
                      1 = ODUE1 letter processed
                      2 = ODUE2 letter processed
                      C = ODUECLAIM letter generated

ENDUSAGE

die $usage if $arg->{help};

if (   not($arg->{hostname}) && ( $arg->{doClaimletters} || $arg->{removeStale} )   ) {
    die "You must define the hostname parameter when using --removestale or --claimletters\n\n$usage";
}

unless ($arg->{doClaimletters} || $arg->{doOverdues} || $arg->{removeStale}) {
    die "You must requests either/or to send claim letters or overdue notifications\n\n$usage";
}

#Run claiming first because it is dependent on spotting unsent ODUE2-letters
if ($arg->{doClaimletters}) {
    open(my $curl_cmd  ,  "/usr/bin/curl -s ".$arg->{hostname}."/cgi-bin/koha/svc/rebuildClaimletters.pl |");
    print <$curl_cmd>;
    close($curl_cmd);
}
C4::OPLIB::Claiming::processODUE1andODUE2( $arg ) if $arg->{doOverdues};

print strftime('%H:%M:%S',localtime).' > SCRIPT FINISHED'."\n" if $arg->{verbose};
