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
use Carp;

use C4::OPLIB::AcquisitionIntegration;
use C4::OPLIB::SelectionListProcessor;
use C4::ImportBatch;

use Getopt::Long;
use Try::Tiny;
use Scalar::Util qw(blessed);
use File::Basename;

use Koha::Exception::DuplicateObject;
use Koha::Exception::RemoteInvocation;
use Koha::Exception::BadEncoding;
use Koha::Exception::SystemCall;
use Koha::Exception::File;

binmode( STDOUT, ":utf8" );
binmode( STDERR, ":utf8" );

my ($kv_selects, $btj_selects, $btj_biblios, $help);
my $verbose = 0;

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
my $ftp = C4::OPLIB::AcquisitionIntegration::connectToKirjavalitys();
if ( $help ) {
    print $usage;
}
unless ( $kv_selects || $btj_selects || $btj_biblios ) {
    print $usage;
    die "ERROR: you must define atleast one of these\n--kv_selects\n--btj_selects";
}

my $listdirectory = '/tmp/'; #Where to store selection lists
my $stagedFileVerificationDuration_days = 700; #Stop looking for selection lists older than this when staging MARC for the Koha reservoir
                                               #Be aware that the Koha cleanup_database.pl -script also removes the imported lists.
my $importedSelectionlists = getImportedSelectionlists();

my $now = DateTime->now();
my $year = strftime( '%Y', localtime() );


my $errors = []; #Collect all the errors here!

#We don't throw a warning for these files if they are present in the FTP server root directory.
my $kvFtpExceptionFiles = { 'marcarkisto' => 1,
                            'Order' => 1,
                            'tmp' => 1,
                            'heinavesi' => 1,
                            'varkaus' => 1,
                            'pieksamaki' =>1
                          };



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

    my $vendorConfig = C4::OPLIB::AcquisitionIntegration::getVendorConfig('Kirjavalitys');

    getAllKirjavalitysSelectionlists($kvenn_selectionlist_filenames, $kvulk_selectionlist_filenames);

    processKirjavalitysSelectionlistType($vendorConfig, $kvenn_selectionlist_filenames, 'ennakot');
    processKirjavalitysSelectionlistType($vendorConfig, $kvulk_selectionlist_filenames, 'ulkomaiset');

    if (scalar @$errors) {
        print "\nFOLLOWING ERRORS WERE FOUND!\n".
                "----------------------------\n".
                join "\n", @$errors;
    }
}
sub processKirjavalitysSelectionlistType {
    my ($vendorConfig, $selectionListBatches, $listType) = @_;

    my $ftp = Koha::FTP->new( C4::OPLIB::AcquisitionIntegration::connectToKirjavalitys() );
    my $selectionListProcessor = C4::OPLIB::SelectionListProcessor->new({listType => $listType});

    my @directories = ("/tmp/varkaus/", "/tmp/heinavesi/", "/tmp/pieksamaki/");
    my $i = 0;

    #Go through all the required directories
    foreach(@directories){
        #Check if the required directory exists
        if(-d @directories[$i]){
            #Everything is allright here
            print "Required directory '@directories[$i]' exists!\n";
        }else{
            #Here we have to create the missing directory
            print "Required directory '@directories[$i]' is missing. Creating the required directory...\n";
            mkdir @directories[$i], 0755;
            print "Required directory '@directories[$i]' created.\n";
        }

        $i++;
    }

    for(my $i = 0 ; $i < scalar @$selectionListBatches ; $i++) {
        try {
            my $selectionListBatch = $selectionListBatches->[$i];

            #Splitting selectionListBatch to get a working filepath
            my $index = index($selectionListBatch, "/", 1);
            my $directory = substr $selectionListBatch, 0, $index;
            my $marc = "/marcarkisto/";

            my $merged_directory = $directory;

            print "Importing $selectionListBatch\n" if $verbose > 1;

            $selectionListBatch =~ /(\d{8})\./;
            my $ymd = $1;

            $ftp->get($selectionListBatch, $listdirectory.$selectionListBatch);

            verifyCharacterEncoding($listdirectory, $selectionListBatch, $vendorConfig->{selectionListEncoding});

            ##Split the incoming selection list to sub selection lists based on the 971$d
            my $selectionLists = $selectionListProcessor->splitToSubSelectionListsFromFile({
                                                        file => $listdirectory.$selectionListBatch,
                                                        encoding => $vendorConfig->{selectionListEncoding},
                                                        singleList => $selectionListBatch,
                                                        format => $vendorConfig->{selectionListFormat},
                                                    });

            stageSelectionlists($selectionLists, $vendorConfig->{selectionListEncoding}, $listType, $ymd);
            moveKirjavalitysSelectionListBatch($listdirectory.$selectionListBatch, $merged_directory, $ftp);

        } catch {
            if (blessed($_)) {
                warn $_->error()."\n";
                push @$errors, $_->error();
#                next(); #Perl bug here. next() doesn't point to the foreach loop here but possibly to something internal to Try::Tiny.
                 #Thus we get the "Exiting subroutine via next" -warning. Because there are no actions after the catch-statement,
                 #this doesn't really hurt here, but just a remnder for anyone brave enough to venture further here.
            }
            else { 
                #die "Exception not caught by try-catch:> ".$_;
                print "Exception not caught by try-catch:> ".$_;
            }
        };
    }
    $ftp->quit();
}

sub getAllKirjavalitysSelectionlists {
    my ($kvenn_selectionlist_filenames, $kvulk_selectionlist_filenames) = @_;

    my $ftpcon = C4::OPLIB::AcquisitionIntegration::connectToKirjavalitys();

    my $ftpfiles = $ftpcon->ls();
    foreach my $clients (@$ftpfiles) {
        my $client = $ftpcon->ls("/".$clients);
        foreach my $file (@$client) {
            if ($file =~ /kvmarcxmlenn\d{8}\.xml/) {
                print "Kirjavalitys: Found file: $file\n" if $verbose;
                push @$kvenn_selectionlist_filenames, $file;
            }elsif ($file =~ /kvmarcxmlulk\d{8}\.xml/) {
                print "Kirjavalitys: Found file: $file\n" if $verbose;
                push @$kvulk_selectionlist_filenames, $file;
            }elsif ($kvFtpExceptionFiles->{$file}) {
                #We have a list of files that are allowed to be in the KV ftp directory and we won't warn about.
            }
            else {
                print "Kirjavalitys: Unknown file in ftp-server '$file'\n";
            }
        }
    }

    $ftpcon->close();

    @$kvenn_selectionlist_filenames = sort @$kvenn_selectionlist_filenames;
    @$kvulk_selectionlist_filenames = sort @$kvulk_selectionlist_filenames;
}

=head stageSelectionlist
@THROWS Koha::Exception::SystemCall
=cut

sub stageSelectionlist {
    my ($selectionList, $encoding, $listType) = @_;

    my ($batch_id, $num_valid_records, $num_items, @import_errors) =
        C4::ImportBatch::BatchStageMarcRecords('biblio', $encoding, $selectionList->getMarcRecords(), $selectionList->getIdentifier(), undef, $selectionList->getDescription(), '', 0, 0, 100, undef);
    print join("\n",
    "MARC record staging report for selection list ".$selectionList->getIdentifier(),
    "------------------------------------",
    "Number of input records:    ".scalar(@{$selectionList->getMarcRecords()}),
    "Number of valid records:    $num_valid_records",
    "------------------------------------",
    ((scalar(@import_errors)) ? (
    "Errors",
    "@import_errors",
    "",)
    :
    "",
    )
    );
}

=head stageFromFileSelectionlist

This function is used to import the btj full bibliographic records.
@THROWS Koha::Exception::SystemCall
=cut

sub stageFromFileSelectionlist {
    my ($filePath, $comment, $encoding) = @_;

    ##Push the Kirjavälitys selection list to staged records batches.
    my @args = ($ENV{KOHA_PATH}.'/misc/stage_file.pl',
                '--file '.$filePath,
                '--encoding '.$encoding,
                '--match 1',
                '--comment "'.$comment.'"',
                '--format ISO2709');

    system("@args") == 0 or Koha::Exception::SystemCall->throw(error => "system @args failed: $?");
    return 0; #No errors wooee!
}

sub stageSelectionlists {
    my ($selectionLists, $encoding, $listType, $ymd) = @_;

    my $errors = '';
    while( my ($newName, $sl) =  each %$selectionLists) {
        try {
            #We directly stage these selection lists so we can better control their descriptions and content and get nicer output.
            isSelectionListImported( $sl->getIdentifier() );
            stageSelectionlist($sl, $encoding, $listType);
        } catch {
            if (blessed($_)){
                if ($_->isa('Koha::Exception::SystemCall')) {
                    warn $_->error()."\n";
                    $errors .= $_->error()."\n";
                }
                else {
                    $_->rethrow();
                }
            }
            else {
                die $_;
            }
        };
    }
    Koha::Exception::SystemCall->throw(error => $errors) if $errors && length $errors > 0;
}

=head moveKirjavalitysSelectionListBatch
Aknowledge the reception by moving the selectionListBatches to marcarkisto-directory
=cut

sub moveKirjavalitysSelectionListBatch {
    my ($filePath, $targetDirectory, $ftp) = @_;
    my($fileName, $dirs, $suffix) = File::Basename::fileparse( $filePath );
    print "HERE: $filePath\n" if $verbose;

    #Variables used for getting the file's directory
    my $firstslash = rindex($filePath, "/");
    my $secondslash = rindex($filePath, "/", $firstslash-1);

    #Getting the file's directory as a string
    my $delDirectory = substr $filePath, $secondslash, $firstslash - $secondslash + 1;

    my $currentDir = $ftp->getCurrentFtpDirectory();
    $ftp->changeFtpDirectory($targetDirectory);
    $ftp->put($filePath);
    $ftp->changeFtpDirectory($delDirectory); #FIXME: These two rows must be uncommented for this to work perfectly
    $ftp->delete($fileName);
    print "$fileName\n";
}










##############
## BTJ HERE ##
##############
sub forBTJ {
    print "Starting for BTJ\n" if $verbose;

    #Prepare all the files to look for in the KV ftp-server
    my $ma_selectionlist_filenames = [];
    my $mk_selectionlist_filenames = [];

    my $vendorConfig = C4::OPLIB::AcquisitionIntegration::getVendorConfig('BTJSelectionLists');

    getAllBTJSelectionlists($ma_selectionlist_filenames, $mk_selectionlist_filenames);

    processBTJSelectionlistType($vendorConfig, $ma_selectionlist_filenames, 'av-aineisto');
    processBTJSelectionlistType($vendorConfig, $mk_selectionlist_filenames, 'kirja-aineisto');

    if (scalar @$errors) {
        print "\nFOLLOWING ERRORS WERE FOUND!\n".
                "----------------------------\n".
                join "\n", @$errors;
    }
}
sub processBTJSelectionlistType {
    my ($vendorConfig, $selectionListBatches, $listType) = @_;

    my $ftp = Koha::FTP->new( C4::OPLIB::AcquisitionIntegration::connectToBTJselectionLists() );
    my $selectionListProcessor = C4::OPLIB::SelectionListProcessor->new({listType => $listType});

    for(my $i = 0 ; $i < scalar @$selectionListBatches ; $i++) {
        try {
            my $selectionListBatch = $selectionListBatches->[$i];

            print "Importing $selectionListBatch\n" if $verbose > 1;

            $selectionListBatch =~ /(\d{4})/;
            my $md = $1;

            $ftp->get($selectionListBatch, $listdirectory.$selectionListBatch);

            verifyCharacterEncoding($listdirectory, $selectionListBatch, $vendorConfig->{selectionListEncoding});

            ##Split the incoming selection list to sub selection lists based on the 971$d
            my $selectionLists = $selectionListProcessor->splitToSubSelectionListsFromFile({
                                                        file => $listdirectory.$selectionListBatch,
                                                        encoding => $vendorConfig->{selectionListEncoding},
                                                        singleList => $selectionListBatch,
                                                        format => $vendorConfig->{selectionListFormat},
                                                    });

            stageSelectionlists($selectionLists, $vendorConfig->{selectionListEncoding}, $listType, $md);

        } catch {
            if (blessed($_)) {
                if ($_->isa('Koha::Exception::DuplicateObject')) {
                    #print $_->error()."\n";
                    #It is normal for BTJ to find the same selection lists again and again,
                    #because they keep the selection lists from the past month.
                }
                else {
                    warn $_->error()."\n";
                    push @$errors, $_->error();
                }
#                next(); #Perl bug here. next() doesn't point to the foreach loop here but possibly to something internal to Try::Tiny.
                 #Thus we get the "Exiting subroutine via next" -warning. Because there are no actions after the catch-statement,
                 #this doesn't really hurt here, but just a remnder for anyone brave enough to venture further here.
            }
            else { 
                #Giving the command print instead of die allows as to continue while ignoring possible errors.
                print "Exception not caught by try-catch:> ".$_;
            }
        };
    }
    $ftp->quit();
}
sub getAllBTJSelectionlists {
    my ($ma_selectionlist_filenames, $mk_selectionlist_filenames) = @_;

    my $ftpcon = C4::OPLIB::AcquisitionIntegration::connectToBTJselectionLists();
    my $vendorConfig = C4::OPLIB::AcquisitionIntegration::getVendorConfig('BTJSelectionLists');
    my $ftpfiles = $ftpcon->ls();
    my $filePickRegexp = qr($vendorConfig->{filePickRegexp});
    foreach my $file (@$ftpfiles) {
        if ($file =~ /$filePickRegexp/) { #Pick only files of specific format
            #Subtract file's date from current date.
            #The year must be selected, but there is no way of knowing which year is set on the selection list files so using arbitrary 2000
            my $difference_days = Date::Calc::Delta_Days(2000,$1,$2,2000,$now->month(),$now->day());

            if ( $difference_days >= 0 && #If the year changes there is trouble, because during subtraction year is always the same
                 $difference_days < $stagedFileVerificationDuration_days) { #if selection list is too old, skip trying to stage it.

                if ($file =~ /xmk$/) {
                    print "BTJ: Found file: $file\n" if $verbose;
                    push @$ma_selectionlist_filenames, $file;
                }elsif ($file =~ /xk$/) {
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

sub forBTJBiblios {
    print "Starting BTJ biblios\n" if $verbose;

    #Prepare all the files to look for in the KV ftp-server
    my $ma_selectionlist_filenames = [];
    my $mk_selectionlist_filenames = [];

    my $vendorConfig = C4::OPLIB::AcquisitionIntegration::getVendorConfig('BTJBiblios');

    getAllBTJBibliolists($ma_selectionlist_filenames, $mk_selectionlist_filenames);

    processBTJBibliolistType($vendorConfig, $ma_selectionlist_filenames, 'av-aineisto');
    processBTJBibliolistType($vendorConfig, $mk_selectionlist_filenames, 'kirja-aineisto');

    if (scalar @$errors) {
        print "\nFOLLOWING ERRORS WERE FOUND!\n".
                "----------------------------\n".
                join "\n", @$errors;
    }
}
sub processBTJBibliolistType {
    my ($vendorConfig, $bibliosBatches, $listType) = @_;

    my $ftp = Koha::FTP->new( C4::OPLIB::AcquisitionIntegration::connectToBTJbiblios() );

    for(my $i = 0 ; $i < scalar @$bibliosBatches ; $i++) {
        try {
            my $bibliosBatch = $bibliosBatches->[$i];

            ##Inject a year into the batch filename when receiving it, so it won't get confused with same named Biblio batches from last year.
            my $localBatchFileName;
            unless ($bibliosBatch =~ /^(B)(\d\d\d\d)(\D+)$/) {
                Koha::Exception::File->throw(error => "processBTJBibliolistType():> Couldn't parse the Biblios Batch filename '$bibliosBatch' using regexp ".'/^(B)(\d\d\d\d)(\D+)$/'.". Cannot inject the year to the filename :(");
            }
            $localBatchFileName = "${year}_$1$2$3";

            isSelectionListImported( $localBatchFileName );

            $bibliosBatch =~ /(\d{4})/;
            my $md = $1;

            $ftp->get($bibliosBatch, $listdirectory.$localBatchFileName);

            stageFromFileSelectionlist($listdirectory.$localBatchFileName, 'List type '.$listType, $vendorConfig->{biblioEncoding});
        } catch {
            if (blessed($_)) {
                if ($_->isa('Koha::Exception::DuplicateObject')) {
                    #It is normal for BTJ to find the same selection lists again and again,
                    #because they keep the selection lists from the past month.
                }
                else {
                    warn $_->error()."\n";
                    push @$errors, $_->error();
                }
#                next(); #Perl bug here. next() doesn't point to the foreach loop here but possibly to something internal to Try::Tiny.
                 #Thus we get the "Exiting subroutine via next" -warning. Because there are no actions after the catch-statement,
                 #this doesn't really hurt here, but just a remnder for anyone brave enough to venture further here.
            }
            else { 
                die "Exception not caught by try-catch:> ".$_;
            }
        };
    }

    #Always check and try to commit files, if previous errors!
    my $error = commitStagedFiles('B\d\d\d\dm[ak]');
    if ($error) {
        push @$errors, $error;
        next();
    }

    $ftp->quit();
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
    my $selectionlist = lc( shift );

    if (exists $importedSelectionlists->{$selectionlist}) {
        Koha::Exception::DuplicateObject->throw(error => "Selection list $selectionlist already imported.")
    }
}

=head commitStagedFiles
Warning, this function actually pushes the imported batch into the live DB instead of the reservoir.
=cut

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

sub verifyCharacterEncoding {
    my ($listdirectory, $selectionlist, $marc_encoding) = @_;
    ##Inspect the character encoding of the selection list
    my $fileType = `file -bi $listdirectory$selectionlist`;
    chomp $fileType;
    if (  not($fileType =~ /utf-?8/i) && not($fileType =~ /us-?ascii/i)  ) {
        Koha::Exception::BadEncoding->throw(error => "Selection list '$selectionlist' is of type '$fileType', expected '$marc_encoding'");
    }
    elsif ( $verbose > 1 ) {
        print "Filetype $fileType\n";
    }
}
