#! /usr/bin/perl
# IN THIS FILE #
#
# Connects to our booksellers services to fetch the selection lists and stages them to the MARC reservoir
# Calls the /misc/stage_file.pl to do the dirty staging!

use Modern::Perl;

use Net::FTP;
use POSIX qw/strftime/;
use DateTime;
use Date::Calc;
use Data::Dumper;

use C4::OPLIB::AcquisitionIntegration;
use Getopt::Long;

my ($kv_selects, $btj_selects, $btj_biblios, $verbose, $help);

GetOptions(
    'kv-selects'  => \$kv_selects,
    'btj-selects' => \$btj_selects,
    'btj-biblios'   => \$btj_biblios,
    'verbose=i'       => \$verbose,
    'h|help'        => \$help,
);

my $usage = "
pullSelectionListsFromBookvendors.pl :
Copies MARC ISO -files from bookvendors distribution services and stages them to Koha.

This script takes the following parameters :

    --kv-selects        Stage Kirjavälitys' selection lists from their acquisitions ftp-server to Koha,
                        so we can make orders from their catalogue.

    --btj-selects       Stage BTJ's selection lists from their acquisitions ftp-server to Koha,
                        so we can make orders from their catalogue.

    --btj-biblios       USE THIS ONLY ON THE SEPARATE Z39.50 OVERLAY CONTAINER kohacatalogs.
                        Stages BTJ's fully catalogued biblios from their ftp server to Koha.
                        Then push the staged files to the biblios table. This screws up our
                        production catalog if this script is ran there.
                        ONLY FOR THE SEPARATE Z39.50 CONTAINER!

    --verbose | v       verbose. An integer, 1 for slightly verbose, 2 for largely verbose!
";

if ( $help ) {
    print $usage;
}
unless ( $kv_selects || $btj_selects || $btj_biblios ) {
    print $usage;
    die "ERROR: you must define atleast one of these\n--kv_selects\n--btj_selects";
}

my $listdirectory = '/tmp/'; #Where to store selection lists
my $stagedFileVerificationDuration_days = 700; #Stop looking for selection lists older than this when staging MARC for the Koha reservoir
my $importedSelectionlists = getImportedSelectionlists();

my $now = DateTime->now();
my $year = strftime( '%Y', localtime() );


my $errors = []; #Collect all the errors here!


##Starting subroutine definitions##
##  bookseller specific processing starts from the for<Vendorname>()-subroutine.

##############
## KIRJAVÄLITYS HERE ##
##############
sub forKirjavalitys {
    print "Starting for Kirjavalitys\n" if $verbose;
    #Prepare all the files to look for in the KV ftp-server
    my $kvenn_selectionlist_filenames = [];
    my $kvulk_selectionlist_filenames = [];

    getAllKirjavalitysSelectionlists($kvenn_selectionlist_filenames, $kvulk_selectionlist_filenames);
    my $marc_encoding = 'utf8';

    processKirjavalitysSelectionlistType($marc_encoding, $kvenn_selectionlist_filenames, 'ennakot');
    processKirjavalitysSelectionlistType($marc_encoding, $kvulk_selectionlist_filenames, 'ulkomaiset');

    if (scalar @$errors) {
        print "\nFOLLOWING ERRORS WERE FOUND!\n".
                "----------------------------\n".
                join "\n", @$errors;
    }
}
sub processKirjavalitysSelectionlistType {
    my ($marc_encoding, $selectionlists, $listType) = @_;

    my $ftpcon = C4::OPLIB::AcquisitionIntegration::connectToKirjavalitys();

    my $firstrun = 1;
    for(my $i = 0 ; $i < scalar @$selectionlists ; $i++) {
        my $selectionlist = $selectionlists->[$i];

        if (isSelectionListImported( $selectionlist )) {
            print "Selection list $selectionlist already imported.\n" if $verbose;
            next; #Don't try to reimport a selection list!
        }
        print "Importing $selectionlist\n" if $verbose > 1;

        $selectionlist =~ /(\d{8})\./;
        my $ymd = $1;

        my $error = getKirjavalitysSelectionlist($listdirectory, $selectionlist, $ftpcon);
        if ($error) {
            #Store the error for today only!
            push @$errors, $error if $firstrun;
            $firstrun = 0 if $firstrun;
            next();
        }

        $error = stageKirjavalitysSelectionlist($listdirectory, $selectionlist, $marc_encoding, $listType, $ymd);
        if ($error) {
            #If we cannot stage a file for some reason, we must store the error!
            push @$errors, $error;
            $firstrun = 0 if $firstrun;
            next();
        }

        $error = deleteKirjavalitysSelectionlist($listdirectory, $selectionlist, $ftpcon);
        if ($error) {
            #If we cannot delete the selection list, we must report!
            push @$errors, $error;
            $firstrun = 0 if $firstrun;
            next();
        }

        $firstrun = 0 if $firstrun;
    }
    $ftpcon->quit();
}
sub getAllKirjavalitysSelectionlists {
    my ($kvenn_selectionlist_filenames, $kvulk_selectionlist_filenames) = @_;

    my $ftpcon = C4::OPLIB::AcquisitionIntegration::connectToKirjavalitys();

    my $ftpfiles = $ftpcon->ls();
    foreach my $file (@$ftpfiles) {
        if ($file =~ /^kvmarcxmlenn\d+/) {
            print "Kirjavalitys: Found file: $file\n" if $verbose;
            push @$kvenn_selectionlist_filenames, $file;
        }elsif ($file =~ /^kvmarcxmlulk\d+/) {
            print "Kirjavalitys: Found file: $file\n" if $verbose;
            push @$kvulk_selectionlist_filenames, $file;
        }
    }
    $ftpcon->close();

    @$kvenn_selectionlist_filenames = sort @$kvenn_selectionlist_filenames;
    @$kvulk_selectionlist_filenames = sort @$kvulk_selectionlist_filenames;
}
sub getKirjavalitysSelectionlist {
    my ($directory, $filename, $ftpcon) = @_;

    ##getKirjavalitysSelectionlist to /tmp
    if($ftpcon->get($filename, $directory.$filename)) {
        return 0; #Great! no errors!
    }else {
        return "Cannot fetch the selection list $filename from Kirjavälitys' ftp server: ".$ftpcon->message;
    }
}
sub stageKirjavalitysSelectionlist {
    my ($directory, $filename, $encoding, $listType, $ymd) = @_;
    $ymd =~ s/(\d\d\d\d)(\d\d)(\d\d)/$1.$2.$3/;
    ##Push the Kirjavälitys selection list to staged records batches.
    my @args = ($ENV{KOHA_PATH}.'/misc/stage_file.pl',
                '--file '.$directory.$filename,
                '--encoding '.$encoding,
                '--match 1',
                '--comment "Kirjavälitys '.$ymd.' '.$listType.' valintalista"');

    system("@args") == 0 or return "system @args failed: $?";
    return 0; #No errors wooee!
}
##Delete the selection list to acknowledge the reception.
sub deleteKirjavalitysSelectionlist {
    my ($directory, $filename, $ftpcon) = @_;
    my $error = '';

    if ($ftpcon->delete($filename)) {
        #Great!
    }else {
        $error .= "Cannot delete the selection list $filename from Kirjavälitys' ftp server: ".$ftpcon->message;
    }
    if (-e $directory.$filename) {
        my $cmd = "rm $directory$filename";
        system( $cmd ) == 0 or $error .= "system $cmd failed: $?";
    }else {
        $error .= "The selection list $directory$filename doesn't exist even if it has been successfully staged?"
    }
    return $error if length $error > 1;
}







##############
## BTJ HERE ##
##############
sub forBTJ {
    print "Starting for BTJ\n" if $verbose;

    #Prepare all the files to look for in the KV ftp-server
    my $ma_selectionlist_filenames = [];
    my $mk_selectionlist_filenames = [];

    getAllBTJSelectionlists($ma_selectionlist_filenames, $mk_selectionlist_filenames);

    my $marc_encoding = 'MARC-8';

    processBTJSelectionlistType($marc_encoding, $ma_selectionlist_filenames, 'av-aineisto');
    processBTJSelectionlistType($marc_encoding, $mk_selectionlist_filenames, 'kirja-aineisto');

    if (scalar @$errors) {
        print "\nFOLLOWING ERRORS WERE FOUND!\n".
                "----------------------------\n".
                join "\n", @$errors;
    }
}
sub processBTJSelectionlistType {
    my ($marc_encoding, $selectionlists, $listType) = @_;

    my $ftpcon = C4::OPLIB::AcquisitionIntegration::connectToBTJselectionLists();

    my $firstrun = 1;
    for(my $i = 0 ; $i < scalar @$selectionlists ; $i++) {
        my $selectionlist = $selectionlists->[$i];

        if (isSelectionListImported( $selectionlist )) {
            print "Selection list $selectionlist already imported.\n" if $verbose;
            next; #Don't try to reimport a selection list!
        }
        print "Importing $selectionlist\n" if $verbose > 1;

        $selectionlist =~ /(\d{4})/;
        my $md = $1;

        my $error = getBTJSelectionlist($listdirectory, $selectionlist, $ftpcon);
        if ($error) {
            #Store the error for today only!
            push @$errors, $error if $firstrun;
            $firstrun = 0 if $firstrun;
            next();
        }

        $error = stageBTJSelectionlist($listdirectory, $selectionlist, $marc_encoding, $listType, $md);
        if ($error) {
            #If we cannot stage a file for some reason, we must store the error!
            push @$errors, $error;
            $firstrun = 0 if $firstrun;
            next();
        }
        #WITH BTJ we don't delete items like we do with Kirjavälitys
        #$error = deleteBTJSelectionlist($listdirectory, $selectionlist, $ftpcon);
        #if ($error) {
        #    #If we cannot delete the selection list, we must report!
        #    push @$errors, $error;
        #    $firstrun = 0 if $firstrun;
        #    next();
        #}

        $firstrun = 0 if $firstrun;
    }
    $ftpcon->quit();
}
sub getAllBTJSelectionlists {
    my ($ma_selectionlist_filenames, $mk_selectionlist_filenames) = @_;

    my $ftpcon = C4::OPLIB::AcquisitionIntegration::connectToBTJselectionLists();

    my $ftpfiles = $ftpcon->ls();
    foreach my $file (@$ftpfiles) {
        if ($file =~ /U011-(\d\d)(\d\d)\D/) { #Pick only files of specific format
            #Subtract file's date from current date.
            #The year must be selected, but there is no way of knowing which year is set on the selection list files so using arbitrary 2000
            my $difference_days = Date::Calc::Delta_Days(2000,$1,$2,2000,$now->month(),$now->day());

            if ( $difference_days >= 0 && #If the year changes there is trouble, because during subtraction year is always the same
                 $difference_days < $stagedFileVerificationDuration_days) { #if selection list is too old, skip trying to stage it.

                if ($file =~ /ma$/) {
                    print "BTJ: Found file: $file\n" if $verbose;
                    push @$ma_selectionlist_filenames, $file;
                }elsif ($file =~ /mk$/) {
                    print "BTJ: Found file: $file\n" if $verbose;
                    push @$mk_selectionlist_filenames, $file;
                }
            }
            else {
                print "BTJ: Skipping file $file due to \$stagedFileVerificationDuration_days\n" if $verbose > 1;
            }
        }
    }
    $ftpcon->close();

    @$ma_selectionlist_filenames = sort @$ma_selectionlist_filenames;
    @$mk_selectionlist_filenames = sort @$mk_selectionlist_filenames;
}
sub getBTJSelectionlist {
    my ($directory, $filename, $ftpcon) = @_;

    ##getKirjavalitysSelectionlist to /tmp
    if($ftpcon->get($filename, $directory.$filename)) {
        return 0; # No errors! yay!
    }else {
        return "Cannot fetch the selection list $filename from BTJ's ftp server: ".$ftpcon->message;
    }
}
sub stageBTJSelectionlist {
    my ($directory, $filename, $encoding, $listType, $ymd) = @_;
    $ymd =~ s/(\d\d)(\d\d)/$year.$1.$2/;

    ##Push the Kirjavälitys selection list to staged records batches.
    my @args = ($ENV{KOHA_PATH}.'/misc/stage_file.pl',
                '--file '.$directory.$filename,
                '--encoding '.$encoding,
                '--match 1',
                '--comment "BTJ '.$ymd.' '.$listType.' valintalista"');

    system("@args") == 0 or return "system @args failed: $?";
    return 0; #No errors wooee!
}
##Delete the selection list to acknowledge the reception.
=head Don't really delete BTJ's selection lists from the ftp! This is onl for kirjavälitys and code is preserved for later use.
sub deleteBTJSelectionlist {
    my ($directory, $filename, $ftpcon) = @_;
    my $error = '';

    if ($ftpcon->delete($filename)) {
        #Great!
    }else {
        $error .= "Cannot delete the selection list $filename from BTJ's ftp server: ".$ftpcon->message;
    }
    if (-e $directory.$filename) {
        my $cmd = "rm $directory$filename";
        system( $cmd ) == 0 or $error .= "system $cmd failed: $?";
    }else {
        $error .= "The selection list $directory$filename doesn't exist even if it has been successfully staged?"
    }
    return $error if length $error > 1;
}
=cut

sub forBTJBiblios {
    print "Starting BTJ biblios\n" if $verbose;

    #Prepare all the files to look for in the KV ftp-server
    my $ma_selectionlist_filenames = [];
    my $mk_selectionlist_filenames = [];

    getAllBTJBibliolists($ma_selectionlist_filenames, $mk_selectionlist_filenames);

    my $marc_encoding = 'MARC-8';

    processBTJBibliolistType($marc_encoding, $ma_selectionlist_filenames, 'av-aineisto');
    processBTJBibliolistType($marc_encoding, $mk_selectionlist_filenames, 'kirja-aineisto');

    if (scalar @$errors) {
        print "\nFOLLOWING ERRORS WERE FOUND!\n".
                "----------------------------\n".
                join "\n", @$errors;
    }
}
sub processBTJBibliolistType {
    my ($marc_encoding, $selectionlists, $listType) = @_;

    my $ftpcon = C4::OPLIB::AcquisitionIntegration::connectToBTJbiblios();

    my $firstrun = 1;
    for(my $i = 0 ; $i < scalar @$selectionlists ; $i++) {
        my $selectionlist = $selectionlists->[$i];

        if (isSelectionListImported( $selectionlist )) {
            next; #Don't try to reimport a selection list!
        }

        $selectionlist =~ /(\d{4})/;
        my $md = $1;

        my $error = getBTJSelectionlist($listdirectory, $selectionlist, $ftpcon);
        if ($error) {
            #Store the error for today only!
            push @$errors, $error if $firstrun;
            $firstrun = 0 if $firstrun;
            next();
        }

        $error = stageBTJSelectionlist($listdirectory, $selectionlist, $marc_encoding, $listType, $md);
        if ($error) {
            #If we cannot stage a file for some reason, we must store the error!
            push @$errors, $error;
            $firstrun = 0 if $firstrun;
            next();
        }


        #WITH BTJ we don't delete items like we do with Kirjavälitys
        #$error = deleteBTJSelectionlist($listdirectory, $selectionlist, $ftpcon);
        #if ($error) {
        #    #If we cannot delete the selection list, we must report!
        #    push @$errors, $error;
        #    $firstrun = 0 if $firstrun;
        #    next();
        #}

        $firstrun = 0 if $firstrun;
    }

    #Always check and try to commit files, if previous errors!
    my $error = commitStagedFiles('B\d\d\d\dm[ak]');
    if ($error) {
        push @$errors, $error;
        $firstrun = 0 if $firstrun;
        next();
    }

    $ftpcon->quit();
}
sub getAllBTJBibliolists {
    my ($ma_selectionlist_filenames, $mk_selectionlist_filenames) = @_;

    my $ftpcon = C4::OPLIB::AcquisitionIntegration::connectToBTJbiblios();

    my $ftpfiles = $ftpcon->ls();
    foreach my $file (@$ftpfiles) {
        if ($file =~ /B(\d\d)(\d\d)\D/) { #Pick only files of specific format
            #Subtract file's date from current date.
            #The year must be selected, but there is no way of knowing which year is set on the selection list files so using arbitrary 2000
            my $difference_days = Date::Calc::Delta_Days(2000,$1,$2,2000,$now->month(),$now->day());

            if ( $difference_days >= 0 && #If the year changes there is trouble, because during subtraction year is always the same
                 $difference_days < $stagedFileVerificationDuration_days) { #if selection list is too old, skip trying to stage it.

                if ($file =~ /ma$/) {
                    print "BTJ: Found file: $file\n" if $verbose;
                    push @$ma_selectionlist_filenames, $file;
                }elsif ($file =~ /mk$/) {
                    print "BTJ: Found file: $file\n" if $verbose;
                    push @$mk_selectionlist_filenames, $file;
                }
            }
        }
    }
    $ftpcon->close();

    @$ma_selectionlist_filenames = sort @$ma_selectionlist_filenames;
    @$mk_selectionlist_filenames = sort @$mk_selectionlist_filenames;
}




forKirjavalitys() if $kv_selects;
forBTJ()          if $btj_selects;
forBTJBiblios()   if $btj_biblios;



######################
## Common functions ##
######################
#get a koha.import_batches-rows which are not too old
# These are processed to a searchable format.
sub getImportedSelectionlists {
    my $dbh = C4::Context->dbh();

    my $sth = $dbh->prepare('SELECT file_name FROM import_batches WHERE (TO_DAYS(curdate())-TO_DAYS(upload_timestamp)) < ? ORDER BY file_name;');
    $sth->execute(  $stagedFileVerificationDuration_days  );
    my $ary = $sth->fetchall_arrayref();

    #Get the filename from the path for all SELECTed filenames/paths
    my $fns = {}; #hash of filenames!
    foreach my $filename (@$ary) {
        my @a = split("/",$filename->[0]);
        my $basename = lc(   @a[ (scalar(@a)-1) ]   );
        $fns->{ $basename } = 1 if scalar @a > 0; #Take the last value! filename from path.
        print 'Found existing staged selection list '.$filename->[0]."\n" if $verbose > 1;
    }
    return $fns;
}
sub isSelectionListImported {
    my $filename = lc( shift );

    if (exists $importedSelectionlists->{$filename}) {
        return 1;
    }
    return 0;
}
sub commitStagedFiles {
    my ($matching_regexp) = @_;
    my $errors = '';

    #Get the record batch numbers that are just staged
    my @batch_numbers;
    open(my $OUT, '$KOHA_PATH/misc/commit_file.pl --list-batches | grep -P "'.$matching_regexp.'" | grep -P "staged" |') or die 'Couldn\'t run $KOHA_PATH/misc/commit_files.pl: '.$!;
    while (<$OUT>) {
        my $staged_file = $_;
        if ($staged_file =~ /^\s+(\d+)\s+.*?staged\s*$/) {
            push @batch_numbers, $1;
            print "Commit: Found batch-number $1\n" if $verbose;
        }
        else {
            $errors .= "commit_file.pl output format has changed or failed! Couldn't find the staged file's batch-number from:\n  < $staged_file >\n";
        }
    }
    close $OUT;

    #Commit all the staged record batches/biblio lists
    foreach my $batch_number (@batch_numbers) {
        open(my $COMMIT_OUT, '$KOHA_PATH/misc/commit_file.pl --batch-number '.$batch_number.' |') or die 'Couldn\'t run $KOHA_PATH/misc/commit_files.pl --batch_number '.$batch_number.': '.$!;
        while (<$COMMIT_OUT>) { print $_; }
        close $COMMIT_OUT;
    }

    return $errors;
}
