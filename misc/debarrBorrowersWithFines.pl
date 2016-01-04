#!/usr/bin/perl

use Modern::Perl;
use Getopt::Long;

use C4::Accounts;
use Koha::Borrower::Debarments;

my ($help, $confirm, $message, $expiration, $file);
GetOptions(
    'h|help'         => \$help,
    'c|confirm:s'    => \$confirm,
    'm|message:s'    => \$message,
    'f|file:s'       => \$file,
    'e|expiration:s' => \$expiration,
);

my $HELP = <<HELP;

debarrBorrowersWithFines.pl

Creates a debarment for all Borrowers who have fines.

    -h --help       This friendly reminder!

    -c --confirm    Confirm that you want to make your Patrons MAD by barring
                    them from your library because they have ANY unpaid fines.

    -m --message     MANDATORY. The description of the debarment visible to the end-user.
                     or
    -f --messagefile MANDATORY. The file from which to read the message content.

    -e --expiration OPTIONAL. When does the debarment expire?
                    As ISO8601 date, eg  '2015-12-31'


EXAMPLE:

    debarrBorrowersWithFines.pl --confirm -m "This is a description of you bad deeds"
That did almost work.

    debarrBorrowersWithFines.pl -c MAD -m "You didn't play by our rules!" -e '2015-12-31'
    debarrBorrowersWithFines.pl -c MAD -f "/home/koha/kohaclone/messagefile"
This works. Always RTFM.

HELP

if ($help) {
    print $HELP;
    exit 0;
}
elsif (not($confirm) || $confirm ne 'MAD' || (not($message || $file) )) {
    print $HELP;
    exit 1;
}
elsif (not($file) && not(length($message) > 20)) {
    print $HELP;
    print "\nYour --message is too short. A proper message to your end-users must be longer than 20 characters.\n";
    exit 1;
}

my $badBorrowers = C4::Accounts::GetAllBorrowersWithUnpaidFines();
$message = getMessageContent();

foreach my $bb (@$badBorrowers) {
    #Don't crash, but keep debarring as long as you can!
    eval {
        my $success = Koha::Borrower::Debarments::AddDebarment({
            borrowernumber => $bb->{borrowernumber},
            expiration     => $expiration,
            type           => 'MANUAL',
            comment        => $message,
        });
    };
    if ($@) {
        print $@."\n";
    }
}

=head getMessageContent
Gets either the textual message or slurps a file.
=cut

sub getMessageContent {
    return $message if ($message);
    open(my $FH, "<:encoding(UTF-8)", $file) or die "$!\n";
    my @msg = <$FH>;
    close $FH;
    return join("",@msg);
}