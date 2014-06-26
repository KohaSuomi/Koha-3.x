package C4::OPLIB::ClaimletterText;

use Modern::Perl;
use utf8;

use C4::Context;
use Encode qw(encode);
use POSIX;
use DateTime;

use C4::OPLIB::Claiming;


my $pageCharaterWidth = 80;


=head writeClaimletter
$document = OpenOffice::Document
$branch = The Branch object where these $issueDatas originate from
$guarantor = The Borrower who is charged of these overdues
$issueDatas = Array of database columns depicting tables borrower+issues+items of the overdue items.
=cut


## Preparing the .odt
# File where to store the temporary .odt claimletter email attachment
sub buildText {
    my %p = @_;

    my $letterBuilder = [];
    #use Data::Dumper;
    #die Dumper( %p );
    ##Building the long claimletters list .odt
    foreach my $branchcode ( keys %{$p{claimletters}} ) {

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

            writeClaimletter($letterBuilder, $branch, $guarantor, $issueDatas, $p{odueClaimPrice});
        }

        pop @$letterBuilder; #Remove the last element (page break)

        #Close the OODocument
        my $filename = $p{claimletterOdtDirectory} . $p{odtFilename} . $branchcode . '.txt';
        open(my $txt, ">", $filename) or die "Couldn't write the .odt to $filename! ".$!;
            print $txt join "\n", @$letterBuilder;
        close $txt;
    }

}


sub writeClaimletter {
    my ($letterBuilder, $branch, $guarantor, $issueDatas, $odueClaimPrice) = @_;

    #Sorting the $issuesDatas array so the borrowers come in order. This makes it easy to iterate each separate borrower completely.
    $issueDatas = [sort {$a->{borrowernumber} cmp $b->{borrowernumber}} @$issueDatas];

    my $now = DateTime->now;    $now = $now->day() . '.' . $now->month() . '.' . $now->year();

    my $branchtext = "$branch->{branchname}    puh. $branch->{branchphone}\n";
    $branchtext .= $branch->{branchaddress1} if $branch->{branchaddress1};
    $branchtext .= ' ' if $branch->{branchaddress1} && $branch->{branchaddress2};
    $branchtext .= $branch->{branchaddress2} if $branch->{branchaddress2};
    $branchtext .= ", $branch->{branchzip} $branch->{branchcity}";
    push @$letterBuilder, $branchtext;
    push @$letterBuilder, "\n";
    push @$letterBuilder, ''.C4::OPLIB::Claiming::getNameForLetter($guarantor);
    push @$letterBuilder, ''.C4::OPLIB::Claiming::getAddressForLetter($guarantor);
    push @$letterBuilder, "\n\n";
    push @$letterBuilder, "PERINTÄKIRJE $now";
    my $text = ''."PYYDÄMME PALAUTTAMAAN OHEISEN AINEISTON VÄLITTÖMÄSTI.\nELLEI AINEISTOA PALAUTETA, LÄHETÄMME LASKUN.";# $text = encode('UTF-8', $text , Encode::FB_CROAK);
    push @$letterBuilder, $text;
    push @$letterBuilder, "";

    my $totalFinesCount = 0; #Sum all the fines for this guarantor
    my $issuePerpetratorNumber = 0;
    my $issuePerpetratorNumberOld = -1; #Using -1 to trigger borrower information printing for the first issue perpetrator
    foreach my $is ( @{$issueDatas} ) {
        #See if the guarantor is the same as perpetrator, perpetrator is the guarantor if the issue records borrowernumber == guarantors borrowernumber
        $issuePerpetratorNumber = ($guarantor->{borrowernumber} != $is->{borrowernumber}) ? $is->{borrowernumber} : $guarantor->{borrowernumber};

        #If the perpetrator changes, print a new borrower description.
        if ($issuePerpetratorNumber != $issuePerpetratorNumberOld) {
            my $perpetrator = C4::OPLIB::Claiming::getCachedMember( $issuePerpetratorNumber );
            push @$letterBuilder, "Lainaajan nimi: ".C4::OPLIB::Claiming::getNameForLetter($perpetrator)." \t Nro $perpetrator->{cardnumber}";
            push @$letterBuilder, "";
        }
        my $duedate = $is->{date_due}->day() . '.' . $is->{date_due}->month() . '.' . $is->{date_due}->year();
        my $issuedate = $is->{issuedate}->day() . '.' . $is->{issuedate}->month() . '.' . $is->{issuedate}->year();
        my $overdueFee = C4::OPLIB::Claiming::getOverduefee($is->{itemnumber}, $is->{borrowernumber});
        $overdueFee = sprintf(  "%.2f", $overdueFee  ) if $overdueFee;
        my $replacementprice = ($is->{replacementprice}) ? $is->{replacementprice} : 0;
        $replacementprice = sprintf(  "%.2f", $replacementprice  ) if $replacementprice;
        $totalFinesCount += $overdueFee + $replacementprice;

        no warnings;
        push @$letterBuilder, "$is->{author}: $is->{title}"; #float
        push @$letterBuilder, "Materiaali: $is->{itype}, Nide: $is->{barcode}, Luokka: $is->{itemcallnumber}"; #float
        push @$letterBuilder, "Eräpäivä: $duedate, Lainattu: $issuedate $branch->{branchname}sta"; #float
        use warnings;

        push @$letterBuilder, floatRight("Hinta $replacementprice€") if $replacementprice;
        push @$letterBuilder, floatRight("Myöhästymismaksu $overdueFee€") if $overdueFee;
        push @$letterBuilder, '' if $overdueFee || $replacementprice;

        $issuePerpetratorNumberOld = $issuePerpetratorNumber;
    }
    $totalFinesCount += $odueClaimPrice;
    $totalFinesCount = sprintf(  "%.2f", $totalFinesCount  );

    push @$letterBuilder, "";
    push @$letterBuilder, floatRight('Perimiskulut '.sprintf(  "%.2f", $odueClaimPrice  ).'€'); #float
    push @$letterBuilder, floatRight('---------------------------------------------------'); #float
    push @$letterBuilder, floatRight('Kaikki maksut yhteensä '.$totalFinesCount.'€'); #float
    push @$letterBuilder, floatRight('=============================='); #float
    $text = ''.'Korvaushinta peritään vain niiden niteiden osalta, joita ei palauteta.'; #$text = encode('UTF-8', $text , Encode::FB_CROAK);
    push @$letterBuilder, $text;

    push @$letterBuilder, "\f"; #form feed aka page break
}

sub floatRight {
    my $text = shift;

    my $l = length $text;

    return sprintf("%70s",$text);
}

return 1;
