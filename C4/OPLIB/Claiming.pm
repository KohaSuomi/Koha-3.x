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
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package C4::OPLIB::Claiming;

use Modern::Perl;
use utf8;

use C4::Context;
use C4::Letters;
use C4::Accounts;
use C4::Items;
use C4::Message;
use Getopt::Long;
use Mail::Sendmail;
use Encode qw(encode);
use OpenOffice::OODoc;
use POSIX;
use DateTime;
use DateTime::Format::MySQL;
use MIME::Lite;
use Net::FTP;

use C4::OPLIB::ClaimletterOdt;
use C4::OPLIB::ClaimletterText;

use Koha::Borrower::Debarments;
use Koha::DateUtils;

#binmode STDOUT, ":encoding(UTF-8)";


my $help = 0;
my $verbose = 0;

my $claimBranches; #The list of branches whose claim items to gather
my $closeClaim = 0;
my $asZip = 0;


##Caches all the loaded Branches
my $branches = {};
##Caches all the loaded Borrowers
my $borrowers = {};

## Directory where the created claimletters .odt is stored for email attaching.
my $claimletterOdtDirectory = $ENV{KOHA_PATH} ?
                                  $ENV{KOHA_PATH} . '/koha-tmpl/static_content/claiming/' :
                                  $ENV{DOCUMENT_ROOT} . '/static_content/claiming/' ;
my $claimletterOldClaimsOdtDirectory = $claimletterOdtDirectory.'/old_claims/';
my $overdueletterDirectory  = $ENV{KOHA_PATH} ?
                                  $ENV{KOHA_PATH} . '/koha-tmpl/static_content/overdueletters/' :
                                  $ENV{DOCUMENT_ROOT} . '/static_content/overdueletters/';
my $odtFilename = 'perintakirjeet_'.strftime('%Y%m%d',localtime).'_';

my ($odue1Price, $odue2Price, $odueClaimPrice) = split( '\|',C4::Context->preference('claimingFines') );
my $kohaAdminEmail = C4::Context->preference('KohaAdminEmailAddress');

my $dbh = C4::Context->dbh;





#########################################
### DEALING WITH ODUE1 && ODUE2 FIRST ###
#########################################
## Sending the letters to print service provider
sub processODUE1andODUE2 {
    #Catch arguments
    my $args = $_[0];
    die "$args must be a hash of arguments, not a ".ref($args)."." if( $args && ref($args) ne 'HASH' );
    $verbose = 1 if $args->{verbose};

    #Start fussing
    system("mkdir -p $overdueletterDirectory");

    print "\n------------------------------------------------------\n".strftime('%H:%M:%S',localtime).'>Gathering eLetters (ODUE1 ODUE2) for sending'."\n------------------------------------------------------\n" if $verbose;

    my $message_queue_objects = gatherOverdues();


    print "\n------------------------------------------------------\n".strftime('%H:%M:%S',localtime).'>Processing eLetters (ODUE1 ODUE2) for sending'."\n------------------------------------------------------\n" if $verbose;
    if (@$message_queue_objects > 1) {
        if (  sendODUE1andODUE2toEnfo( $message_queue_objects )  ) {

            ##Mark all ODUE1 and ODUE2 print messages as status = 'sent'
            markODUEsasSent_and_ManualInvoice($message_queue_objects, 'sent');
        }
        else {
            warn 'FAIL: eLetters sending failed '.strftime('%Y.%m.%d %H:%M:%S',localtime)."!\n";
        }
    }
}

sub gatherOverdues {
    ## First SELECT relevant messages

    #OLD ONE PRESERVED FOR NOW
    my $selectAllNotSentODUEMessagesSQL = <<SQL;
        SELECT * FROM message_queue
        WHERE (status = 'pending' || status = 'failed') AND message_transport_type = 'print'
        AND (letter_code = 'ODUE1' OR letter_code = 'ODUE2')
        GROUP BY borrowernumber, letter_code;
SQL
    #DO NOT SEND ODUE2 IF ODUE1 is pending to be sent
    $selectAllNotSentODUEMessagesSQL = <<SQL;
        SELECT * FROM message_queue
        WHERE (status = 'pending' || status = 'failed') AND message_transport_type = 'print'
        AND (letter_code = 'ODUE1' OR ( letter_code = 'ODUE2' AND borrowernumber NOT IN (SELECT borrowernumber FROM message_queue WHERE letter_code = 'ODUE1' AND (status = 'pending' || status = 'failed') AND borrowernumber IN (SELECT borrowernumber FROM message_queue WHERE letter_code = 'ODUE2' AND (status = 'pending' || status = 'failed')) ) ))
        GROUP BY borrowernumber, letter_code;
SQL

    my $sth = $dbh->prepare( $selectAllNotSentODUEMessagesSQL );
    $sth->execute( );


    my $message_queue_objects = []; #Collect the verified real message_queues to send
    ##Iterate the message_queue-rows (eletters) and prepare them for transport
    while ( my $message_queue = $sth->fetchrow_hashref() ) {

        my $finePerpetratorNumber = $message_queue->{borrowernumber}; #The borrowernumber for the borrower who caused this claim to happen
        my $letter_code = $message_queue->{letter_code};
        my $content = $message_queue->{content};
        my $finePerpetrator = getCachedMember( $finePerpetratorNumber );
        my $claimBarcodes;
        my $contentBuilder = postprocess_eLetter( $finePerpetratorNumber, $content );

        my $verifiedContent->[0] = $contentBuilder->[0]; #Store the header element
        my $barcodes = [];
        ## Make sure we won't be claiming Items that have already been checked in or renewed.
        foreach my $item (@$contentBuilder) {
            if ($item =~ / 1Nide: (\S+)/m) {
                my $barcode = $1;

                if (verifyClaimBarcode($finePerpetratorNumber, $barcode)) {
                    push @$verifiedContent, $item;
                    push @$barcodes, $barcode;
                }
                else {
                    #print "catch";
                }
            }
        }

        #If we have nothing to claim after all. Mark the message_queue-row as sent.
        #There is always the header element present in $verifiedContent, hence "> 1"!
        if( scalar(@$verifiedContent) <= 1 || $finePerpetrator->{categorycode} eq 'KIRJASTO' || $finePerpetrator->{categorycode} eq 'KOTIPALVEL') {
            $message_queue->{status} = 'sent';
            updateMessage_queue($message_queue);
            next();
        }
        #Store stuff to the $message_queue-object
        $message_queue->{verified_barcodes} = $barcodes;
        $message_queue->{verified_contentBuilder} = $verifiedContent;

        push @$message_queue_objects, $message_queue;
    }
    return $message_queue_objects;
}

## eLetters have space for only 7 item details per page, so new pages must be started for such item lists.
##   each item starts with a <%<eLetter1>%> -tag
## other modifications?
sub postprocess_eLetter {
    my $finePerpetratorNumber = shift;
    my $content = shift;
    $content =~ s/(\d\d\d\d)-(\d\d)-(\d\d) (\d{1,2}):(\d{1,2}):(\d{1,2})/$3.$2.$1/sg;
    $content =~ s/(\d\d)\/(\d\d)\/(\d\d\d\d)/$1.$2.$3/sg;
    my @cS = $content =~ /(.*?)(?=<%<eKirje1>)?/s; #Sometimes we can get letters with no pending Items. Still catch the content header
    my $contentStart = $cS[0];
    chop $contentStart; #Remove the last newline so it wont screw up epl-format
    chop $contentStart;
    #chop $contentStart;
    #chop $contentStart;
    my @items = $content =~ /<%<eKirje1>%>(.*?)<%<eKirje2>%>/sg; #Get the overdue items

    my @stringBuilder;
    push @stringBuilder, $contentStart;

    my $i = 0;
    foreach my $item (@items) {

        if ($i != 0  &&  $i % 7 == 0) { #Start a new page after seven items
            push @stringBuilder, "10\n31";
        }

        push @stringBuilder, $item;

        $i++;
    }
    #return $contentStart[0] . join "\n", @stringBuilder;
    return \@stringBuilder;
}

## Interface to print service provider ##
sub sendODUE1andODUE2toEnfo {
    my $message_queue_objects = shift;

    ##Prepare the file to send!
    my $file = $overdueletterDirectory.'JNS190_'.strftime('%Y%m%d',localtime).'.epl';
    open(my $eKirje, ">:encoding(UTF-8)", $file) or die "Couldn't write to the temp file $file for sending to Enfo Zender";

    #Write the eLetter header
    print $eKirje "EPL1180055438800T002S  0                $kohaAdminEmail\n";
    #Iterate the message_queue-objects and their contentBuilders, which contain verified message Items.
    foreach my $message_queue (@$message_queue_objects) {
        foreach my $message_element ( @{$message_queue->{verified_contentBuilder}} ) {
            print $eKirje $message_element . "\n";
        }
    }
    close $eKirje;
    my $ftpcon = getFtpToEnfo();
    if (! (ref($ftpcon) =~ /Net::FTP/)) {
        print $ftpcon; #IF we don't get a blessed reference there is an error!
    }
    else {
        #$ftpcon->mkdir("kohatest"); #Simply for testing purposes is this row.

        #$ftpcon->cwd("kohatest") or die "Cannot change working directory ", $ftpcon->message;

        $ftpcon->put( $file ) or die "Sending eKirje '$file' to Enfo failed:", $ftpcon->message;

        $ftpcon->close();
        foreach my $message_queue (@$message_queue_objects) {
            #Mark these messages as sent so we can safely close them from the koha.message_queue-table
            $message_queue->{sent_ok} = 1;
        }

        return 1; #Sending succeeded!
    }
    return 0; #Something happened and the sending failed
}
sub getFtpToEnfo {
    my $ftpcon = Net::FTP->new(Host => 'teppo.enfo.fi',
                         Timeout => 10) or return "Cannot connect to ENFO's ftp server: $@";

    if ($ftpcon->login('jns','kefa4gu')){
        return $ftpcon;
    }
    else {
        return "Cannot login to ENFO's ftp server: $@";
    }
}

my $updateMessage_queueMessageSent = "UPDATE message_queue SET status = ?, content = ? WHERE message_id = ?";
sub markODUEsasSent_and_ManualInvoice {
    my $message_queue_objects = shift;
    my $status = shift;

    my $sth = $dbh->prepare( $updateMessage_queueMessageSent );

    foreach my $message_queue (@$message_queue_objects) {
        if ($message_queue->{sent_ok}) {

            $sth->execute( $status, $message_queue->{content}, $message_queue->{message_id} );

            my @manualInvoiceNote = map {
                my $itemnumber = C4::Items::GetItemnumberFromBarcode($_);
                my $item = C4::Circulation::GetItem( $itemnumber );
                buildManualInvoiceNote($item)
            } @{$message_queue->{verified_barcodes}};

            #Add a processing fine for sending a snail mail.
            if ($message_queue->{letter_code} eq 'ODUE1') {
                C4::Accounts::manualinvoice(  $message_queue->{borrowernumber}, undef, '1. Myöhästymismuistutuskirjemaksu', $message_queue->{letter_code}, $odue1Price, "Viivakoodit: " . join(' ',@manualInvoiceNote)  );
                print '1' if $verbose;
            }
            elsif ($message_queue->{letter_code} eq 'ODUE2') {
                C4::Accounts::manualinvoice(  $message_queue->{borrowernumber}, undef, '2. Myöhästymismuistutuskirjemaksu', $message_queue->{letter_code}, $odue2Price, "Viivakoodit: " . join(' ',@manualInvoiceNote)  );
                print '2' if $verbose;
            }
        }
    }
}
sub updateMessage_queue {
    my $message_queue_row = shift;

    my $sth = $dbh->prepare( $updateMessage_queueMessageSent );

    $sth->execute( $message_queue_row->{status}, $message_queue_row->{content}, $message_queue_row->{message_id} );
}

sub buildManualInvoiceNote {
    my $issueData = shift;

    return
    '<a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber='.$issueData->{biblionumber}.'&itemnumber='.$issueData->{itemnumber}.'#item'.$issueData->{itemnumber}.'">'.
      $issueData->{barcode}.
    '</a>';
}




#########################
### SENDING ODUECLAIM ###
#########################

sub processODUECLAIM {
    #Catch arguments
    my $args = $_[0];
    die "$args must be a hash of arguments, not a ".ref($args)."." if( $args && ref($args) ne 'HASH' );

    $verbose = 1 if(exists $args->{verbose});
    $closeClaim = 1 if(exists $args->{closeclaim});

    #Make holdingbranch filters easily searchable by hashing them
    foreach my $branchcode ( @{$args->{claimbranches}} ) {
        $claimBranches->{$branchcode} = 1;
    }

    #Start fussing
    system("mkdir -p $claimletterOdtDirectory");

    print "\n------------------------------------------------------\n".strftime('%H:%M:%S',localtime).'>Gathering Claim letters (ODUECLAIM)'."\n------------------------------------------------------\n" if $verbose;

    my ($message_queue_notClaimedBarcodesMap, $claimletters) = gatherClaimletters();

    if (! scalar(%$claimletters)) { #If we have no claimletters!
        return 0; #Do nuffing
    }

    #Get all the .odts generated
    my $generatedFiles = [];
    foreach my $branchcode ( keys %$claimletters ) {
        push @$generatedFiles, "$claimletterOdtDirectory$odtFilename$branchcode";
    }


    print "\n------------------------------------------------------\n".strftime('%H:%M:%S',localtime).'>Processing Claim letters (ODUECLAIM)'."\n------------------------------------------------------\n" if $verbose;

    C4::OPLIB::ClaimletterOdt::buildOdts( claimletters => $claimletters,
                odtFilename => $odtFilename,
                claimletterOdtDirectory => $claimletterOdtDirectory,
                odueClaimPrice => $odueClaimPrice
             );
    C4::OPLIB::ClaimletterText::buildText( claimletters => $claimletters,
                odtFilename => $odtFilename,
                claimletterOdtDirectory => $claimletterOdtDirectory,
                odueClaimPrice => $odueClaimPrice
             );

    if ($closeClaim) {
    #    sendClaimlettersToBranches( $claimletters, $odtFilename ); #This is no longer required and is preserved just for code reuse.
        markODUECLAIMasSent_and_ManualInvoice($claimletters, $message_queue_notClaimedBarcodesMap);
        moveClosedOdtsToOld_claims($generatedFiles);
    }

    #if ($asZip || $closeClaim) { #Preserved for code reuse purposes
    #    my @args = ('zip', '-j',
    #                $claimletterOdtDirectory.'perintakirjeet_'.strftime('%Y%m%d',localtime).'.zip',
    #                $claimletterOdtDirectory.'perintakirjeet_'.strftime('%Y%m%d',localtime).'_*.odt');
    #    system("@args") or die "Couldn't zip claim letters! ".$!;
    #}

    #Return all the files generated on this run, so we can either send one file to the user, or redirect to the index.
    return $generatedFiles;
}

sub gatherClaimletters {

    ## Collect all the barcodes of borrowers per branch here, so we can send a claiming letter from each branch.
    my $claimletters = {};
    ## Collect all not claimed barcodes per message_queue_id. Remove barcodes from here when they are claimed or checked in.
    ##  This is used after closing claims for a branch to keep track of the message_queue-entries which still contain claimable barcodes.
    ##  Some message_queue ODUECLAIM-letters contain barcodes from multiple holdingbranches and that is a pain.
    my $message_queue_notClaimedBarcodesMap = {};

    ## First SELECT relevant messages
    my $selectAllNotSentODUECLAIMMessagesSQL = <<SQL;
        SELECT * FROM message_queue
        WHERE (status = 'pending' || status = 'failed') AND message_transport_type = 'print'
        AND (letter_code = 'ODUECLAIM')
        GROUP BY borrowernumber, letter_code;
SQL

    #DO NOT SEND ODUECLAIM IF ODUE2 is pending to be sent
    $selectAllNotSentODUECLAIMMessagesSQL = <<SQL;
        SELECT * FROM message_queue
        WHERE (status = 'pending' || status = 'failed') AND message_transport_type = 'print'
        AND ( letter_code = 'ODUECLAIM' AND borrowernumber NOT IN ( SELECT borrowernumber FROM message_queue WHERE letter_code = 'ODUE2' AND (status = 'pending' || status = 'failed') ) )
        GROUP BY borrowernumber, letter_code;
SQL
    my $sth = $dbh->prepare( $selectAllNotSentODUECLAIMMessagesSQL );
    $sth->execute( );

    my $previousFinePerpetratorNumber = 0; #Used to monitor if the borrowernumber changes
    my ($perpetrator, $guarantor); #Guarantor is encumbered by the guarantees fines.

    ##Iterate the message_queue-rows and prepare them for transport
    while ( my $message_queue = $sth->fetchrow_hashref() ) {

        my $finePerpetratorNumber = $message_queue->{borrowernumber}; #The borrowernumber for the borrower who caused this claim to happen
        my $fineGuarantorNumber = $finePerpetratorNumber; #The borrower who caused the fine might not be the one responsible for them.
        my $content = $message_queue->{content};
        $content =~ s/\r//mg; #Remove the carriage returns BAH!
        my @notClaimedBarcodes = $content =~ /^NCB: (\S+)$/mg; #This message might have some of it's barcodes claimed already
        $content =~ s/^NCB: (\S+)$//mg; #Remove NCBs (non claimed barcodes) so they can be appended later when updating claim status.
        $message_queue->{content} = $content;

        ##Make sure we don't include items that are already returned!
        my $verifiedClaimBarcodes = verifyClaimBarcodes($finePerpetratorNumber, \@notClaimedBarcodes);
        my %verifiedClaimBarcodesMap = map {$_ => 1} @$verifiedClaimBarcodes;

        ## If a borrowernumber changes we know we have found the end of the current borrowers snail_mails
        if ($previousFinePerpetratorNumber != $finePerpetratorNumber) {

            $perpetrator = getCachedMember( $message_queue->{borrowernumber} );
            if ($perpetrator->{guarantorid}) {
                $guarantor = getCachedMember( $perpetrator->{guarantorid} );
                $fineGuarantorNumber = $perpetrator->{guarantorid};
            }
        }

        if( scalar(@$verifiedClaimBarcodes) <= 0 || $perpetrator->{categorycode} eq 'KIRJASTO' ) {
            $message_queue->{status} = 'sent';
            updateMessage_queue($message_queue);
            next();
        }

        foreach my $barcode (@$verifiedClaimBarcodes) {
            my $itemnumber = C4::Items::GetItemnumberFromBarcode($barcode);
            my $issueData = C4::Circulation::GetItemIssue( $itemnumber );
            if ((! $issueData) || (! $itemnumber)) { #Important to validate input!
                print "Borrowers ".$perpetrator->{cardnumber}." overdue issue (itemnumber $itemnumber, barcode $barcode) doesn't exist!\n";
                next;
            }

            if (  $claimBranches  &&  not($claimBranches->{ $issueData->{holdingbranch} })  ) {
                next(); #Skip Items not from the desired branches
            }

            ##HACKMAN HERE! REMOVE THIS ENTRY!
#            my $stuff = $issueData->{date_due};
#            $stuff =~ s/T/ /g;
#            my $duedt = DateTime::Format::MySQL->parse_datetime($stuff);
#            my $annex = DateTime->new( year => 2014, month => 4, day => 8 );
#            if ($duedt->epoch() > $annex->epoch()) {
#                next();
#            }


            $issueData->{message_queue} = $message_queue; #Store the message_queue-row so we can later mark it as 'sent'! YAY!

            appendAuthorAndTitle($issueData, $issueData->{biblionumber}); #Put required data elements to the item so it can be used directly to generate Claim list.


            #Set the issue related data columns by branch && borrowernumber for claim letter sending.
            #Collect the claim letters under the guarantor, not the possible child borrower.
            unless ( ref $claimletters->{ $issueData->{holdingbranch} }->{ $fineGuarantorNumber } eq 'ARRAY' ) {
                $claimletters->{ $issueData->{holdingbranch} }->{ $fineGuarantorNumber } = [];
            }
            push @{$claimletters->{ $issueData->{holdingbranch} }->{ $fineGuarantorNumber }}, $issueData;
            $message_queue_notClaimedBarcodesMap->{ $message_queue->{message_id} }->{verifiedClaimBarcodesMap} = \%verifiedClaimBarcodesMap;
            $message_queue_notClaimedBarcodesMap->{ $message_queue->{message_id} }->{message_queue} = $message_queue;

            print 'C' if $verbose;
        }

        ##Update the previous value comparators
        $previousFinePerpetratorNumber = $finePerpetratorNumber;
    }

    return ($message_queue_notClaimedBarcodesMap, $claimletters);
}



#Send the claim letters list to each branch
sub sendClaimlettersToBranches {
    my ($claimletters, $odtFilename) = @_;

    foreach my $branchcode ( keys %$claimletters ) {
        my $branch = getCachedBranchDetail($branchcode);
        unless ( sendClaimlettersToBranch($claimletterOdtDirectory, $odtFilename.$branchcode.'.odt', $branch->{branchemail}, $branchcode) ) {
            print 'FAIL: Claim letters sending failed for branch '.$branch->{branchname}.' time '.strftime('%Y.%m.%d %H:%M:%S',localtime).'!';
        }
        else {
            print "Sent to $branchcode\n" if $verbose;
        }
    }
}

sub markODUECLAIMasSent_and_ManualInvoice {
    my $claimletters = shift;
    my $message_queue_notClaimedBarcodesMap = shift;

    foreach my $branchcode ( keys %$claimletters ) {

        foreach my $guarantorNumber ( keys %{$claimletters->{$branchcode}} ) {

            my $guarantor = getCachedMember( $guarantorNumber );
            my $issueDatas = $claimletters->{$branchcode}->{$guarantorNumber};

            foreach my $issueData (@$issueDatas) {
                my $message_queue = $issueData->{message_queue};
                my $notClaimedBarcodesMap = $message_queue_notClaimedBarcodesMap->{  $message_queue->{message_id}  }->{verifiedClaimBarcodesMap};

                if (exists $notClaimedBarcodesMap->{ $issueData->{barcode} }) {
                    delete $notClaimedBarcodesMap->{ $issueData->{barcode} };
                }
                else {
                    print "How is it possible to claim a not claimable barcode $issueData->{barcode}?"
                }

                #Apparently we don't charge items that are longoverdue? C4::Accounts::chargelostitem( $borrowernumber, $issueData->{itemnumber}, $issueData->{replacementprice}, 'Palauttamatta jätetty nide. Kirjallisesti muistutettu kahdesti.' );
                setItemClaimed( $issueData->{barcode} ); ##Mark the koha.items.itemlost as claimed
            }

            # Add the claiming fee to the guarantor's account
            my @claimBarcodes = map { buildManualInvoiceNote($_) } @$issueDatas; #Collect all the barcodes (as links) claimed from this guarantor
            C4::Accounts::manualinvoice(  $guarantorNumber, undef, 'Perintäkirjemaksu', 'ODUECLAIM', $odueClaimPrice, "Viivakoodit: @claimBarcodes"  );
            Koha::Borrower::Debarments::AddUniqueDebarment(
            {
                borrowernumber => $guarantorNumber,
                type           => 'OVERDUES',
                comment => "Perintäkirjeestä aiheutunut lainauskielto ".
                           Koha::DateUtils::output_pref( Koha::DateUtils::dt_from_string() ),
            }
        );
        }
    }

    ##Find out the $message_queue-objects which have no barcodes left to send, and mark them as 'sent'
    ##Also update the barcodes left to claim.
    foreach my $message_id (keys %$message_queue_notClaimedBarcodesMap) {

        my $message_queue = $message_queue_notClaimedBarcodesMap->{ $message_id }->{message_queue};
        my $notClaimedBarcodesMap = $message_queue_notClaimedBarcodesMap->{ $message_id }->{verifiedClaimBarcodesMap};
        my @notClaimedBarcodesMapKeys = map {'NCB: '.$_} keys %$notClaimedBarcodesMap;

        $message_queue->{content} .= join("\n" , @notClaimedBarcodesMapKeys);

        if (scalar( @notClaimedBarcodesMapKeys )) { #We still have not claimed barcodes, so we cannot close this message_queue-row, we however update the claimed barcodes we just claimed!
            $message_queue->{status} = 'pending';
            updateMessage_queue(  $message_queue  );
        }
        else { #Nothing left to claim for this message_queue-row, so we can close it for good!
            $message_queue->{sent} = 'sent';
            updateMessage_queue(  $message_queue  );
        }
    }
}

sub moveClosedOdtsToOld_claims {
    my $generatedFiles = shift;
    system("mkdir -p $claimletterOldClaimsOdtDirectory"); #Make sure the directory exists!

    for( my $i=0 ; $i<scalar(@$generatedFiles) ; $i++) {
        my $file = $generatedFiles->[$i];
        system("mv $file.odt $claimletterOldClaimsOdtDirectory/");
        system("mv $file.txt $claimletterOldClaimsOdtDirectory/");

        #Update the old $odt to match the new location
        $file =~ s/$claimletterOdtDirectory/$claimletterOldClaimsOdtDirectory/;
        $generatedFiles->[$i] = $file;
    }
}

sub removeStaleOdts {
    #use Data::Dumper;
    #die Data::Dumper::Dumper(%ENV);
    #die $ENV{KOHA_PATH};
    system("rm $claimletterOdtDirectory/*.odt");
    system("rm $claimletterOdtDirectory/*.txt");
}



### End of core script ###
## ------------------------- ##
### Start of helper methods ###

sub sendClaimlettersToBranch {
    use utf8;
    my $odtDir = shift;
    my $odtFile = shift;
    my $emailAddress = shift;
    my $branchcode = shift;

    my $email = MIME::Lite->new(
        To   => $emailAddress,
        From => C4::Context->preference('KohaAdminEmailAddress'),
        Subject => encode('UTF-8', "Perintakirjeet $branchcode", Encode::FB_CROAK),
        Message => '',
        Type => 'multipart/mixed; charset=UTF-8',
    );
    $email->attach(
        Type => 'BINARY',
        Path => $odtDir.$odtFile,
        Filename => $odtFile,
        Disposition => 'attachment',
    );

    if ( $email->send() ) {
        return 1;
    }
    else {
        return 0;
    }
}



sub appendAuthorAndTitle {
    my ($item,$biblionumber) = @_;
    my $dbh            = C4::Context->dbh;
    my $sth            = $dbh->prepare("SELECT author, title FROM biblio WHERE biblionumber = ?");

    $sth->execute($biblionumber);
    if ( my $data = $sth->fetchrow_hashref ) {
        $item->{author} = $data->{author};
        $item->{title} = $data->{title};
    }
}
sub setItemClaimed {
    my ($barcode)      = @_;
    my $dbh            = C4::Context->dbh;
    my $sth            = $dbh->prepare("UPDATE items SET notforloan = 6 WHERE barcode = ?");

    $sth->execute($barcode);
}


sub getOverduefee {
    my ($itemnumber, $borrowernumber) = @_;

    my $dbh        = C4::Context->dbh;
	my $sth = $dbh->prepare(
			"SELECT SUM(amountoutstanding) AS sum FROM accountlines WHERE borrowernumber=? AND itemnumber=? AND accounttype='FU'"
          );
	$sth->execute( $borrowernumber, $itemnumber );

    my $data = $sth->fetchrow_hashref();
    return $data->{sum} ? $data->{sum} : 0;
}

##Branches are repeatedly loaded in various parts of this code. Better to cache them .
sub getCachedBranchDetail {
    my $branchcode = shift; #The hash to store all branches by branchcode

    if (exists $branches->{$branchcode}) {
        return $branches->{$branchcode};
    }
    my $branch = C4::Branch::GetBranchDetail($branchcode);
    $branches->{$branchcode} = $branch;
    return $branch;
}
##Branches are repeatedly loaded in various parts of this code. Better to cache them .
sub getCachedMember {
    my $borrowernumber = shift; #The hash to store all branches by branchcode

    if (exists $borrowers->{$borrowernumber}) {
        return $borrowers->{$borrowernumber};
    }
    my $borrower = C4::Members::GetMember( borrowernumber => $borrowernumber );
    $borrowers->{$borrowernumber} = $borrower;
    return $borrower;
}

sub getNameForLetter {
    my ($borrower) = @_;

    my @stringbuilder;
    push @stringbuilder, $borrower->{surname}.',' if defined $borrower->{surname};
    push @stringbuilder, $borrower->{firstname} if defined $borrower->{firstname};

    return join ' ', @stringbuilder;
}
sub getAddressForLetter {
    my ($borrower) = @_;

    my @stringbuilder1;
    push @stringbuilder1, $borrower->{address} if defined $borrower->{address};
    push @stringbuilder1, $borrower->{address2} if defined $borrower->{address2};
    push @stringbuilder1, $borrower->{streetnumber} if defined $borrower->{streetnumber};
    push @stringbuilder1, $borrower->{streettype} if defined $borrower->{streettype};

    my @stringbuilder2;
    push @stringbuilder2, $borrower->{zipcode} if defined $borrower->{zipcode};
    push @stringbuilder2, $borrower->{city} if defined $borrower->{city};

    return join(' ', @stringbuilder1) . "\n" . join(' ', @stringbuilder2);
}

sub verifyClaimBarcodes {
    my $finePerpetratorNumber = shift;
    my $claimBarcodes = shift;

    my $verifiedClaimBarcodes = [];
    ## Make sure we won't be claiming Items that have already been checked in or renewed.
    foreach my $barcode (@$claimBarcodes) {
        push @$verifiedClaimBarcodes, $barcode if verifyClaimBarcode($finePerpetratorNumber, $barcode);;
    }
    return $verifiedClaimBarcodes;
}
#Make sure the given item is issued to the given borrower and is late
#Also make sure that the given item is not already claimed!
sub verifyClaimBarcode {
    my $finePerpetratorNumber = shift;
    my $claimBarcode = shift;

    #Verify not-claimed
    my $item = C4::Items::GetItem( undef, $claimBarcode );
    return 0 if $item->{notforloan} == 6;

    #Verify issue
    my $issue = C4::Circulation::GetOpenIssue( C4::Items::GetItemnumberFromBarcode( $claimBarcode ) );

    if ($issue &&
        $issue->{borrowernumber} == $finePerpetratorNumber) {

        #my $now = DateTime->now(formatter => 'DateTime::Format::MySQL');
        my $now = time();
        #my $date_due = DateTime::Format::MySQL->parse_datetime( $issue->{date_due} );
        my $date_due = DateTime::Format::MySQL->parse_datetime( $issue->{date_due} )->epoch();
        my $difference = $date_due - $now; #Lets see how many seconds late this issue is
        if ( $difference < 0 ) { #Has the duedate already expired?
            return $claimBarcode; #Duedate is expired, so lets notify this item!
        }
    }
    return 0;
}

sub getClaimletterCountByBranch {

    my $branchCounts = {}; #Collect the branch counts here

    open (my $ls_command, "/bin/ls $claimletterOdtDirectory$odtFilename* |");
    while (<$ls_command>) {
        my $odtFile = $_;
        chomp $odtFile;

        my $holdingbranch;
        if ($odtFile =~ /_([[:alpha:]]+_[[:alpha:]]+)\.odt/) {
            $holdingbranch = $1;
        }
        elsif ($odtFile =~ /_([[:alpha:]]+_[[:alpha:]]+)\.txt/) {
            #It's ok, these files are allowed as well.
            next();
        }
        else {
            die "File $odtFile is not of the proper format and should not be here.";
        }


        use bytes;
        odfLocalEncoding 'utf8';# important!
        odfWorkingDirectory( $claimletterOdtDirectory );

        ##Start the OODocument
        my $document = odfDocument(file => $odtFile);
        if ($document) { #If the file is empty, we get trooble!
            my @separateLetters = $document->getParagraphTextList();
            foreach my $row (@separateLetters) {
                if ($row =~ /PERINTÄKIRJE/) {
                    $branchCounts->{$holdingbranch} = 0 unless exists $branchCounts->{$holdingbranch};
                    $branchCounts->{$holdingbranch} = $branchCounts->{$holdingbranch} + 1;
                }
            }
        }
    #    $document->close();
    }
    close $ls_command;

    return $branchCounts;
}


=head STUFF FROM THE EXPERIMENT OF DRIVING CLAIMING MODULE FROM THE DB!
##CONSERVED IF CLAIMING MODULE NEEDS TO BE REWRITTEN AS DB DRIVEN!
sub get_claiming_items_from_message_queue {
    my $dbh = C4::Context->dbh();

    ## First SELECT relevant messages
    my $selectAllODUECLAIMMessagesSQL = "SELECT * FROM message_queue WHERE letter_code = 'ODUECLAIM'";
    my $removeODUECLAIMMessageSQL = "DELETE FROM message_queue WHERE letter_code = 'ODUECLAIM' AND message_id = ?";

    my $deleteSth = $dbh->prepare( $removeODUECLAIMMessageSQL );
    my $sth = $dbh->prepare( $selectAllODUECLAIMMessagesSQL );
    $sth->execute( );

    my @claiming_items;
    while ( my $message_queue = $sth->fetchrow_hashref() ) {
        my $content = $message_queue->{content};
        $content =~ s/\r//mg; #Remove the carriage returns BAH!
        my @claimBarcodes = $content =~ /^ 1Nide: (\S+)$/mg; #$content has only comment lines and barcodes.

        foreach my $barcode (@claimBarcodes) {
            my $itemnumber = C4::Items::GetItemnumberFromBarcode($barcode);
            my $issueData = C4::Circulation::GetItemIssue( $itemnumber );

            unless( addClaiming_item($itemnumber, $message_queue->{borrowernumber}, $issueData->{date_due}) ) {
                die "Something bad hapened when addClaiming_item($itemnumber, $message_queue->{borrowernumber}, $issueData->{date_due})  ! :(\n";
            }
        }
        $deleteSth->execute( $message_queue->{message_id} );
    }
}

sub addClaiming_item {
    my ($itemnumber, $borrowernumber, $date_due) = @_;

    my $dbh = C4::Context->dbh();

    my $sth = $dbh->prepare("INSERT INTO claiming_items VALUES (NULL,?,?,?,NULL,?,NULL)");

    my $now = DateTime::Format::MySQL->format_datetime(  DateTime->now()  );

    $sth->execute($itemnumber, $borrowernumber, $date_due, $now);

    return 1 unless $sth->err();
}

##FROM updatedatabase.pl
$DBversion = "3.17.00.XXX";
if (CheckVersion($DBversion)) {
    my $sql = <<ASDF;
CREATE TABLE claiming_items (
  `claimingnumber` int(11) NOT NULL auto_increment, -- primary key and unique identifier added by Koha
  `itemnumber` int(11) default NULL, -- soft reference to koha.items.itemnumber or koha.deleteditems.itemnumber or missing
  `borrowernumber` int(11) default NULL, -- soft reference to koha.borrowers.borrowernumber or koha.deletedborrowers.borrowernumber or missing
  `date_due` datetime default NULL, -- datetime the item was due (yyyy-mm-dd hh:mm::ss), trying to id the claimable issue with these top 3 identifier because issues-table has no PK
  `status` varchar(255) default NULL, -- Signal a specific status if necessary.
  `createdate` datetime default NULL, -- the date this claim row is created
  `claimdate` datetime default NULL, -- the date this claim row is created
  PRIMARY KEY  (`claimingnumber`),
  UNIQUE KEY `issueidx` (`itemnumber`,`borrowernumber`,`date_due`),
  KEY `itemnumberidx` (`itemnumber`),
  KEY `borrowernumberidx` (`borrowernumber`),
  KEY `date_dueidx` (`date_due`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
ASDF
    $dbh->do($sql);
    print "Upgrade to $DBversion done (Bug TODO: fill me up scotty)\n";
    SetVersion($DBversion);
}

=cut
return 1; #Happy happy joy joy!
