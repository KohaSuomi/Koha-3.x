package C4::OPLIB::ClaimletterOdt;

use Modern::Perl;
use utf8;

use C4::Context;
use Encode qw(encode);
use OpenOffice::OODoc;
use POSIX;
use DateTime;

use C4::OPLIB::Claiming;

=head writeClaimletter
$document = OpenOffice::Document
$branch = The Branch object where these $issueDatas originate from
$guarantor = The Borrower who is charged of these overdues
$issueDatas = Array of database columns depicting tables borrower+issues+items of the overdue items.
=cut


## Preparing the .odt
# File where to store the temporary .odt claimletter email attachment
sub buildOdts {
    my %p = @_;
    use bytes;

    my $claimlettertemplate = $ENV{KOHA_PATH} ?
                              $ENV{KOHA_PATH} . '/misc/claimlettertemplate.odt' :
                              $ENV{DOCUMENT_ROOT} . '/../misc/claimlettertemplate.odt' ;
    $claimlettertemplate = C4::Context->preference('claimlettertemplate') if C4::Context->preference('claimlettertemplate');

    odfLocalEncoding 'utf8';# important!
    odfWorkingDirectory( $p{claimletterOdtDirectory} );

    ##Building the long claimletters list .odt
    foreach my $branchcode ( keys %{$p{claimletters}} ) {

        ##Start the OODocument
        my $document = odfDocument(file => $claimlettertemplate);
        $document->outputDelimitersOff();
        $document->removeParagraph(0);

        #Get branch details
        my $branch = C4::OPLIB::Claiming::getCachedBranchDetail($branchcode);

        foreach my $guarantorNumber ( sort { #Sort by surname+firstname ascending
                        my $ap = C4::OPLIB::Claiming::getCachedMember($a);
                        my $bp = C4::OPLIB::Claiming::getCachedMember($b);
                        lc($ap->{surname}.$ap->{firstname})
                        cmp
                        lc($bp->{surname}.$bp->{firstname})
                    } keys %{$p{claimletters}->{$branchcode}} ) {

            my $guarantor = C4::OPLIB::Claiming::getCachedMember( $guarantorNumber );
            my $issueDatas = $p{claimletters}->{$branchcode}->{$guarantorNumber};

            writeClaimletter($document, $branch, $guarantor, $issueDatas, $p{odueClaimPrice});
        }

        #Close the OODocument
        my $filename = $p{claimletterOdtDirectory} . $p{odtFilename} . $branchcode . '.odt';
        open(my $odt, ">", $filename) or die "Couldn't write the .odt to $filename! ".$!;
            $document->save( $filename ); #OODoc::File doens't warn if the saving fails so we manually open a filehandle for it.
        close $odt;
    }

}


sub writeClaimletter {
    use bytes;
    my ($document, $branch, $guarantor, $issueDatas, $odueClaimPrice) = @_;

    #Sorting the $issuesDatas array so the borrowers come in order. This makes it easy to iterate each separate borrower completely.
    $issueDatas = [sort {$a->{borrowernumber} cmp $b->{borrowernumber}} @$issueDatas];

    my $now = DateTime->now;    $now = $now->day() . '.' . $now->month() . '.' . $now->year();

    $document->appendParagraph(text => "$branch->{branchname}\n$branch->{branchaddress1} $branch->{branchaddress2}\n$branch->{branchzip} $branch->{branchcity}\npuh. $branch->{branchphone}", style => 'Text body');
    $document->appendParagraph(text => '', style => 'Text body');
    $document->appendParagraph(text => ''.C4::OPLIB::Claiming::getNameForLetter($guarantor), style => 'Text body');
    $document->appendParagraph(text => ''.C4::OPLIB::Claiming::getAddressForLetter($guarantor), style => 'Text body');
    $document->appendParagraph(text => '', style => 'Text body');
    $document->appendParagraph(text => "PERINTÄKIRJE $now", style => 'Heading 3');
    my $text = "PYYDÄMME PALAUTTAMAAN OHEISEN AINEISTON VÄLITTÖMÄSTI.\nELLEI AINEISTOA PALAUTETA, LÄHETÄMME LASKUN, JOKA ON ULOSOTTOKELPOINEN."; $text = encode('UTF-8', $text , Encode::FB_CROAK);
    $document->appendParagraph(text => $text, style => 'Text body');
    $document->appendParagraph(text => '', style => 'Text body');

    my $totalFinesCount = 0; #Sum all the fines for this guarantor
    my $issuePerpetratorNumber = 0;
    my $issuePerpetratorNumberOld = -1; #Using -1 to trigger borrower information printing for the first issue perpetrator
    foreach my $is ( @{$issueDatas} ) {
        #See if the guarantor is the same as perpetrator, perpetrator is the guarantor if the issue records borrowernumber == guarantors borrowernumber
        $issuePerpetratorNumber = ($guarantor->{borrowernumber} != $is->{borrowernumber}) ? $is->{borrowernumber} : $guarantor->{borrowernumber};

        #If the perpetrator changes, print a new borrower description.
        if ($issuePerpetratorNumber != $issuePerpetratorNumberOld) {
            my $perpetrator = C4::OPLIB::Claiming::getCachedMember( $issuePerpetratorNumber );
            $document->appendParagraph(text => "Lainaajan nimi: ".C4::OPLIB::Claiming::getNameForLetter($perpetrator)." \t Nro $perpetrator->{cardnumber}", style => 'Text body');
            $document->appendParagraph(text => '', style => 'Text body');
        }
        my $duedate = $is->{date_due}->day() . '.' . $is->{date_due}->month() . '.' . $is->{date_due}->year();
        my $issuedate = $is->{issuedate}->day() . '.' . $is->{issuedate}->month() . '.' . $is->{issuedate}->year();
        my $overdueFee = C4::OPLIB::Claiming::getOverduefee($is->{itemnumber}, $is->{borrowernumber});
        $overdueFee = sprintf(  "%.2f", $overdueFee  ) if $overdueFee;
        my $replacementprice = ($is->{replacementprice}) ? $is->{replacementprice} : 0;
        $replacementprice = sprintf(  "%.2f", $replacementprice  ) if $replacementprice;
        $totalFinesCount += $overdueFee + $replacementprice;

        no warnings;
        my $itemText =
"$is->{author}: $is->{title}
Materiaali: $is->{itype}, Nide: $is->{barcode}, Luokka: $is->{itemcallnumber}
Eräpäivä: $duedate, Lainattu: $issuedate $branch->{branchname}sta";
        use warnings;

        my $priceText = '';
        $priceText .= "Hinta $replacementprice€" if $replacementprice;
        $priceText .= "\n" if $replacementprice && $overdueFee;
        $priceText .= "Myöhästymismaksu $overdueFee€" if $overdueFee;

        $document->appendParagraph(text => $itemText, style => 'Text body');
        $document->appendParagraph(text => $priceText, style => 'Text Body float right') if $priceText;

        $issuePerpetratorNumberOld = $issuePerpetratorNumber;
    }
    $totalFinesCount += $odueClaimPrice;
    $totalFinesCount = sprintf(  "%.2f", $totalFinesCount  );

    $document->appendParagraph(text => '', style => 'Text Body float right');
    $document->appendParagraph(text => 'Perimiskulut '.sprintf(  "%.2f", $odueClaimPrice  ).'€', style => 'Text Body float right');
    $document->appendParagraph(text => '---------------------------------------------------', style => 'Text Body float right');
    $document->appendParagraph(text => 'Kaikki maksut yhteensä '.$totalFinesCount.'€', style => 'Text Body float right');
    $document->appendParagraph(text => '==============================', style => 'Text Body float right');
    $text = 'Korvaushinta peritään vain niiden niteiden osalta, joita ei palauteta.'; $text = encode('UTF-8', $text , Encode::FB_CROAK);
    $document->appendParagraph(text => $text, style => 'Text body');

    my $latestParagraph = $document->getParagraph(-1);
    $document->setPageBreak($latestParagraph, position => 'after', style => 'Text Body');
}

return 1;
