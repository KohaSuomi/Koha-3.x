package C4::OPLIB::OKM;

use Modern::Perl;
use Carp;

use Data::Dumper;
use URI::Escape;
use File::Temp;
use File::Basename qw( dirname );

use C4::Branch;
use C4::Items;
use C4::OPLIB::OKMLibraryGroup;
use C4::Context qw(dbh);

sub new {
    my ($class, $statisticalYear, $limit) = @_;

    my $self = {};
    bless($self, $class);
    my $libraryGroups = $self->setLibraryGroups(  $self->getOKMBranchCategoriesAndBranches()  );

    $self->{thisYear} = $statisticalYear || (localtime(time))[5] + 1900; #Get the current year
    $self->{thisYearISO} = $self->{thisYear} . '-01-01';
    $self->{limit} = $limit; #Set the SQL LIMIT. Used in testing to generate statistics faster.

    $self->createStatistics();

    return $self;
}

sub createStatistics {
    my ($self) = @_;

    my $libraryGroups = $self->getLibraryGroups();

    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};

        $self->statisticsBranchCounts( $libraryGroup, 1);

        my $sth = $self->fetchItemsDataMountain($libraryGroup);
        while (my $row = $sth->fetchrow_hashref()) {
            $self->_processItemsDataRow( $libraryGroup, $row );
        }

        $self->statisticsSubscriptions( $libraryGroup );
        $self->statisticsDiscards( $libraryGroup );
        $self->statisticsActiveBorrowers( $libraryGroup );

        $self->tidyStatistics( $libraryGroup );
    }
}

=head _processItemsDataRow

    _processItemsDataRow( $row );

@PARAM1 hash, a koha DB row consisting of items, marcxml, aqorder, statistics
=cut

sub _processItemsDataRow {
    my ($self, $libraryGroup, $row) = @_;

    my $stats = $libraryGroup->getStatistics();

    my $primaryLanguage = FindMarcField('041','a',$row->{marcxml});
    my $isChildrensMaterial = IsItemChildrens($row);
    my $isFiction = IsItemFiction($row);
    my $isMusicalRecording = IsItemMusicalRecording($row);
    my $isAcquiredThisYear = IsItemAcquiredThisYear($row, $self->{thisYear});
    my $itemtype = $row->{itype};

    #Increase the collection for every Item found
    $stats->{collection}++;
    $stats->{acquisitions}++ if $isAcquiredThisYear;
    $stats->{issues} += $row->{issues};
    $stats->{expenditureAcquisitions} += $row->{price} if $row->{price};

    if ($itemtype eq 'KI') {

        $stats->{collectionBooksTotal}++;
        $stats->{acquisitionsBooksTotal}++ if $isAcquiredThisYear;
        $stats->{expenditureAcquisitionsBooks} += $row->{price} if $isAcquiredThisYear && $row->{price};
        $stats->{issuesBooksTotal} += $row->{issues};

        if ($primaryLanguage eq 'fin') {
            $stats->{collectionBooksFinnish}++;
            $stats->{acquisitionsBooksFinnish}++ if $isAcquiredThisYear;
            $stats->{issuesBooksFinnish} += $row->{issues};
        }
        elsif ($primaryLanguage eq 'swe') {
            $stats->{collectionBooksSwedish}++;
            $stats->{acquisitionsBooksSwedish}++ if $isAcquiredThisYear;
            $stats->{issuesBooksSwedish} += $row->{issues};
        }
        else {
            $stats->{collectionBooksOtherLanguage}++;
            $stats->{acquisitionsBooksOtherLanguage}++ if $isAcquiredThisYear;
            $stats->{issuesBooksOtherLanguage} += $row->{issues};
        }

        if ($isFiction) {
            if ($isChildrensMaterial) {
                $stats->{collectionBooksFictionJuvenile}++;
                $stats->{acquisitionsFictionJuvenile}++ if $isAcquiredThisYear;
                $stats->{issuesBooksFictionJuvenile} += $row->{issues};
            }
            else { #Adults fiction
                $stats->{collectionBooksFictionAdult}++;
                $stats->{acquisitionsBooksFictionAdult}++ if $isAcquiredThisYear;
                $stats->{issuesBooksFictionAdult} += $row->{issues};
            }
        }
        else { #Non-Fiction
            if ($isChildrensMaterial) {
                $stats->{collectionBooksNonFictionJuvenile}++;
                $stats->{acquisitionsNonFictionJuvenile}++ if $isAcquiredThisYear;
                $stats->{issuesBooksNonFictionJuvenile} += $row->{issues};
            }
            else { #Adults Non-fiction
                $stats->{collectionBooksNonFictionAdult}++;
                $stats->{acquisitionsBooksNonFictionAdult}++ if $isAcquiredThisYear;
                $stats->{issuesBooksNonFictionAdult} += $row->{issues};
            }
        }
    }
    elsif ($itemtype eq 'NU' || $itemtype eq 'PA' || $itemtype eq 'NÄ') {
        $stats->{collectionSheetMusicAndScores}++;
        $stats->{acquisitionsSheetMusicAndScores}++ if $isAcquiredThisYear;
        $stats->{issuesSheetMusicAndScores} += $row->{issues};
    }
    elsif ($itemtype eq 'KA' || $itemtype eq 'CD' || $itemtype eq 'MP' || $itemtype eq 'LE') {
        if ($isMusicalRecording) {
            $stats->{collectionMusicalRecordings}++;
            $stats->{acquisitionsMusicalRecordings}++ if $isAcquiredThisYear;
            $stats->{issuesMusicalRecordings} += $row->{issues};
        }
        else {
            $stats->{collectionOtherRecordings}++;
            $stats->{acquisitionsOtherRecordings}++ if $isAcquiredThisYear;
            $stats->{issuesOtherRecordings} += $row->{issues};
        }
    }
    elsif ($itemtype eq 'VI') {
        $stats->{collectionVideos}++;
        $stats->{acquisitionsVideos}++ if $isAcquiredThisYear;
        $stats->{issuesVideos} += $row->{issues};
    }
    elsif ($itemtype eq 'CR' || $itemtype eq 'DR') {
        $stats->{collectionCDROMs}++;
        $stats->{acquisitionsCDROMs}++ if $isAcquiredThisYear;
        $stats->{issuesCDROMs} += $row->{issues};
    }
    elsif ($itemtype eq 'BR' || $itemtype eq 'DV') {
        $stats->{collectionDVDsAndBluRays}++;
        $stats->{acquisitionsDVDsAndBluRays}++ if $isAcquiredThisYear;
        $stats->{issuesDVDsAndBluRays} += $row->{issues};
    }
    elsif ($itemtype ne 'AL' || $itemtype ne 'SL') { #Serials and magazines are collected from the subscriptions-table using statisticsSubscriptions()
        $stats->{collectionOther}++;
        $stats->{acquisitionsOther}++ if $isAcquiredThisYear;
        $stats->{issuesOther} += $row->{issues};
    }
    else {
        carp "What is this! You shouldn't be here! There is something wrong with this items row containing this biblio:\n".$row->{marcxml};
    }
}

=head fetchItemsDataMountain

    my $sth = $okm->fetchDataMountain();

Queries the DB for the required data elements and returns the DBI Statement to query for results.
Collects both the acquisitions information and statistics information for the given year. These are further separated in the business layer.
=cut

sub fetchItemsDataMountain {
    my ($self, $libraryGroup) = @_;

    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare(
                "SELECT i.itemnumber, i.itype, i.location, i.price, bi.marcxml, ao.ordernumber, ao.datereceived, av.imageurl, i.dateaccessioned,
                        SUM(
                          IF(  s.type IN ('issue','renew') AND YEAR(s.datetime) = YEAR(?) AND
                               (s.usercode = 'HENKILO' OR s.usercode = 'VIRKAILIJA' OR s.usercode = 'LAPSI' OR s.usercode = 'MUUKUINLAP' OR s.usercode = 'TAKAAJA' OR s.usercode = 'YHTEISO'),
                            1,0
                          )
                        ) AS issues
                 FROM items i LEFT JOIN biblioitems bi ON i.biblionumber = bi.biblionumber LEFT JOIN aqorders_items ai ON i.itemnumber = ai.itemnumber
                              LEFT JOIN aqorders ao ON ai.ordernumber = ao.ordernumber LEFT JOIN statistics s ON s.itemnumber = i.itemnumber
                              LEFT JOIN authorised_values av ON av.authorised_value = i.permanent_location
                 WHERE i.homebranch $in_libraryGroupBranches
                 GROUP BY i.itemnumber ORDER BY i.itemnumber $limit;");
    $sth->execute(  $self->{thisYearISO}  ); #This will take some time.....

    return $sth;
}
=head getBranchCounts

    getBranchCounts( $branchcode, $mainLibrariesCount );

Fills OKM columns "Pääkirjastoja, Sivukirjastoja, Laitoskirjastoja, Kirjastoautoja"
1. SELECTs all branches we have.
2. Finds bookmobiles by the regexp /AU$/ in the branchcode
3. Finds bookboats by the regexp /VE$/ in the branchcode
4. Institutional libraries by /JOE_(LA)KO/, where LA stand for LaitosKirjasto.
5. Main libraries cannot be differentiated from branch libraries so this is fed as a parameter to the script.
6. Branch libraries are what is left after picking all previously mentioned branch types.
=cut

sub statisticsBranchCounts {
    my ($self, $libraryGroup, $mainLibrariesCount) = (@_);

    my $stats = $libraryGroup->getStatistics();

    foreach my $branchcode (sort keys %{$libraryGroup->{branches}}) {
        #Get them bookmobiles!
        if ($branchcode =~ /^\w\w\w_\w\w\wAU$/) {  #JOE_JOEAU, JOE_LIPAU
            $stats->{bookmobiles}++;
        }
        #Get them bookboats!
        elsif ($branchcode =~ /^\w\w\w_\w\w\wVE$/) {  #JOE_JOEVE, JOE_LIPVE
            $stats->{bookboats}++;
        }
        #Get them institutional libraries!
        elsif ($branchcode =~ /^\w\w\w_LA\w\w$/) {  #JOE_LAKO, JOE_LASI
            $stats->{institutionalLibraries}++;
        }
        #Get them branch libraries!
        else {
            $stats->{branchLibraries}++;
        }
    }
    #After all is counted, we remove the given main branches from branch libraries and set the main libraries count.
    $stats->{branchLibraries} = $stats->{branchLibraries} - $mainLibrariesCount;
    $stats->{mainLibraries} = $mainLibrariesCount;
}

sub statisticsSubscriptions {
    my ($self, $libraryGroup) = (@_);

    my $dbh = C4::Context->dbh();
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();
    my $sth = $dbh->prepare(
               "SELECT COUNT(subscriptionid) AS count,
                       SUM(IF(  marcxml REGEXP '  <controlfield tag=\"008\">.....................n..................</controlfield>'  ,1,0)) AS newspapers,
                       SUM(IF(  marcxml REGEXP '  <controlfield tag=\"008\">.....................p..................</controlfield>'  ,1,0)) AS magazines
                FROM subscription s LEFT JOIN biblioitems bi ON bi.biblionumber = s.biblionumber
                WHERE branchcode $in_libraryGroupBranches AND YEAR(?) BETWEEN YEAR(startdate) AND YEAR(enddate) $limit");
    $sth->execute( $self->{thisYearISO} );
    my $retval = $sth->fetchrow_hashref();

    my $stats = $libraryGroup->getStatistics();
    $stats->{newspapers} = $retval->{newspapers} if $retval->{newspapers};
    $stats->{magazines} = $retval->{magazines} if $retval->{magazines};

    if ($stats->{newspapers} + $stats->{magazines} != $retval->{count}) {
        carp "Calculating subscriptions, total count ".$stats->{count}." is not the same as newspapers ".$stats->{newspapers}." and magazines ".$stats->{magazines}." combined!";
    }
}
sub statisticsDiscards {
    my ($self, $libraryGroup) = (@_);

    my $dbh = C4::Context->dbh();
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();
    my $sth = $dbh->prepare(
               "SELECT count(*) FROM deleteditems WHERE homebranch $in_libraryGroupBranches AND YEAR(?) = YEAR(timestamp) $limit;");
    $sth->execute( $self->{thisYearISO} );
    my $discards = $sth->fetchrow;

    my $stats = $libraryGroup->getStatistics();
    $stats->{discards} = $discards;
}
sub statisticsActiveBorrowers {
    my ($self, $libraryGroup) = (@_);

    my $dbh = C4::Context->dbh();
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();
    my $sth = $dbh->prepare(
                "SELECT COUNT(stat.borrowernumber) FROM borrowers b
                 LEFT JOIN (
                    SELECT borrowernumber
                    FROM statistics s WHERE s.type IN ('issue','renew') AND YEAR(datetime) = YEAR(?)
                    GROUP BY s.borrowernumber
                 )
                 AS stat ON stat.borrowernumber = b.borrowernumber
                 WHERE b.branchcode $in_libraryGroupBranches $limit");
    $sth->execute( $self->{thisYearISO} );
    my $activeBorrowers = $sth->fetchrow;

    my $stats = $libraryGroup->getStatistics();
    $stats->{activeBorrowers} = $activeBorrowers;
}
sub tidyStatistics {
    my ($self, $libraryGroup) = (@_);
    my $stats = $libraryGroup->getStatistics();
    $stats->{expenditureAcquisitionsBooks} = sprintf("%.2f", $stats->{expenditureAcquisitionsBooks});
    $stats->{expenditureAcquisitions}      = sprintf("%.2f", $stats->{expenditureAcquisitions});
}

sub getLibraryGroups {
    my $self = shift;

    return $self->{lib_groups};
}

=head setLibraryGroups

    setLibraryGroups( $libraryGroups );

=cut

sub setLibraryGroups {
    my ($self, $libraryGroups) = @_;

    croak '$libraryGroups parameter is not a HASH of groups of branchcodes!' unless (ref $libraryGroups eq 'HASH');
    $self->{lib_groups} = $libraryGroups;

    foreach my $groupname (sort keys %$libraryGroups) {
        $libraryGroups->{$groupname} = C4::OPLIB::OKMLibraryGroup->new(  $groupname, $libraryGroups->{$groupname}->{branches}  );
    }
    return $self->{lib_groups};
}

sub verify {
    my $self = shift;
    my $groupsErrors = [];
    my $libraryGroups = $self->getLibraryGroups();

    foreach my $groupcode (sort keys %$libraryGroups) {
        my $stats = $libraryGroups->{$groupcode}->getStatistics();
        if (my $errors = $stats->verifyStatisticalIntegrity()) {
            push @$groupsErrors, @$errors;
        }
    }
    return $groupsErrors if scalar(@$groupsErrors) > 0;
    return undef;
}

=head asHtml

    my $html = $okm->asHtml();

Returns an HTML table header and rows for each library group with statistical categories as columns.
=cut

sub asHtml {
    my $self = shift;
    my @sb;

    my $a;

    my $libraryGroups = $self->getLibraryGroups();

    push @sb, '<table>';
    my $firstrun = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        push @sb, $stat->asHtmlHeader() if $firstrun-- > 0;

        push @sb, $stat->asHtml();
    }
    push @sb, '</table>';

    return join("\n", @sb);
}

=head asCsv

    my $csv = $okm->asCsv();

Returns a csv header and rows for each library group with statistical categories as columns.
=cut

sub asCsv {
    my ($self, $separator) = @_;
    my @sb;

    my $a;

    my $libraryGroups = $self->getLibraryGroups();

    my $firstrun = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        push @sb, $stat->asCsvHeader($separator) if $firstrun-- > 0;

        push @sb, $stat->asCsv($separator);
    }

    return join("\n", @sb);
}

=head asOds

=cut

sub asOds {
    my $self = shift;

    my $ods_fh = File::Temp->new( UNLINK => 0 );
    my $ods_filepath = $ods_fh->filename;

    use OpenOffice::OODoc;
    my $tmpdir = dirname $ods_filepath;
    odfWorkingDirectory( $tmpdir );
    my $container = odfContainer( $ods_filepath, create => 'spreadsheet' );
    my $doc = odfDocument (
        container => $container,
        part      => 'content'
    );
    my $table = $doc->getTable(0);
    my $libraryGroups = $self->getLibraryGroups();

    my $firstrun = 1;
    my $row_i = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        my $headers = $stat->getPrintOrder() if $firstrun > 0;
        my $columns = $stat->getPrintOrderElements();

        if ($firstrun-- > 0) { #Set the table size and print the header!
            $doc->expandTable( $table, scalar(keys(%$libraryGroups))+1, scalar(@$headers) );
            my $row = $doc->getRow( $table, 0 );
            for (my $j=0 ; $j<@$headers ; $j++) {
                $doc->cellValue( $row, $j, $headers->[$j] );
            }
        }

        my $row = $doc->getRow( $table, $row_i++ );
        for (my $j=0 ; $j<@$columns ; $j++) {
            my $value = Encode::encode( 'UTF8', $columns->[$j] );
            $doc->cellValue( $row, $j, $value );
        }
    }

    $doc->save();
    binmode(STDOUT);
    open $ods_fh, '<', $ods_filepath;
    my @content = <$ods_fh>;
    unlink $ods_filepath;
    return join('', @content);
}

=head getOKMBranchCategories

    C4::OPLIB::OKM::getOKMBranchCategories();
    $okm->getOKMBranchCategories();

Searches Koha for branchcategories ending to letters "_OKM".
These branchcategories map to a OKM annual statistics row.

@RETURNS a hash of branchcategories.categorycode = 1
=cut

sub getOKMBranchCategories {
    my $self = shift;
    my $libraryGroups = {};

    my $branchcategories = C4::Branch::GetBranchCategories();
    for( my $i=0 ; $i<@$branchcategories ; $i++) {
        my $branchCategory = $branchcategories->[$i];
        my $code = $branchCategory->{categorycode};
        if ($code =~ /^\w\w\w_OKM$/) { #Catch branchcategories which are OKM statistical groups.
            #HASHify the categorycodes for easy access
            $libraryGroups->{$code} = $branchCategory;
        }
    }
    return $libraryGroups;
}

=head getOKMBranchCategoriesAndBranches

    C4::OPLIB::OKM::getOKMBranchCategoriesAndBranches();
    $okm->getOKMBranchCategoriesAndBranches();

Calls getOKMBranchCategories() to find the branchCategories and then finds which branchcodes are mapped to those categories.

@RETURNS a hash of branchcategories.categorycode -> branches.branchcode = 1
=cut

sub getOKMBranchCategoriesAndBranches {
    my $self = shift;
    my $libraryGroups = $self->getOKMBranchCategories();

    foreach my $categoryCode (keys %$libraryGroups) {
        my $branchcodes = C4::Branch::GetBranchesInCategory( $categoryCode );

        if (not($branchcodes) || scalar(@$branchcodes) <= 0) {
            warn "Statistical library group $categoryCode has no libraries, removing it from OKM statistics\n";
            delete $libraryGroups->{$categoryCode};
            next();
        }

        #HASHify the branchcodes for easy access
        $libraryGroups->{$categoryCode} = {}; #CategoryCode used to be 1, which makes for a poor HASH reference.
        $libraryGroups->{$categoryCode}->{branches} = {};
        my $branches = $libraryGroups->{$categoryCode}->{branches};
        grep { $branches->{$_} = 1 } @$branchcodes;
    }
    return $libraryGroups;
}

=head FindMarcField

Static method

    my $subfieldContent = FindMarcField('041', 'a', $marcxml);

Finds a single subfield effectively.
=cut

sub FindMarcField {
    my ($tagid, $subfieldid, $marcxml) = @_;
    if ($marcxml =~ /<(data|control)field tag="$tagid".*?>(.*?)<\/(data|control)field>/s) {
        my $fieldStr = $2;
        if ($fieldStr =~ /<subfield code="$subfieldid">(.*?)<\/subfield>/s) {
            return $1;
        }
    }
}

=head IsItemChildrens

Static method

    $row->{location} = 'LAP';
    my $isChildrens = IsItemChildrens($row);
    assert($isChildrens == 1);

@PARAM1 hash, containing the koha.items.location as location-key
=cut

sub IsItemChildrens {
    my ($row) = @_;

    my $url = $row->{imageurl}; #Get the items.location -> authorised_values.imageurl

    if ($url && $url =~ /okm_juvenile/) {
        return 1;
    }
    return 0;
}

sub IsItemFiction {
    my ($row) = @_;

    my $sf = FindMarcField('084','a', $row->{marcxml});
    if ($sf =~/^8[1-5].*/) { #ykl numbers 81.* to 85.* are fiction.
        return 1;
    }
    return 0;
}

sub IsItemMusicalRecording {
    my ($row) = @_;

    my $sf = FindMarcField('084','a', $row->{marcxml});
    if ($sf =~/^78.*/) { #ykl number 78 is a musical recording.
        return 1;
    }
    return 0;
}

sub IsItemAcquiredThisYear {
    my ($row, $thisYear) = @_;

    my $receivedYear    = 0;
    my $accessionedYear = 0;
    if ($row->{datereceived} && $row->{datereceived} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) { #Parse ISO date
        $receivedYear = $1;
    }
    if ($row->{dateaccessioned} && $row->{dateaccessioned} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) { #Parse ISO date
        $accessionedYear = $1;
    }

    #This item has been received this year from the vendor
    if ($thisYear == $receivedYear) {
        return 1;
    }
    #This item has been added to Koha this year via acquisitions, but the order hasn't been received yet
    elsif ($accessionedYear == $thisYear && $row->{ordernumber} && not($receivedYear == $thisYear)) {
        return 0;
    }
    #This item has been added to Koha this year outside of the acquisitions
    elsif ($accessionedYear == $thisYear && not($row->{ordernumber})) {
        return 1;
    }
    else {
        return 0;
    }
}

=head getLimit

    my $limit = $self->getLimit();

Gets the SQL LIMIT clause used in testing this feature faster (but not more accurately). It can be passed to the OKM->new() constructor.
=cut

sub getLimit {
    my $self = shift;
    my $limit = '';
    $limit = 'LIMIT '.$self->{limit} if $self->{limit};
    return $limit;
}

=head save

    $okm->save();

Serializes this object and saves it to the koha.okm_statistics-table

=cut

sub save {
    my $self = shift;
    my $dbh = C4::Context->dbh();

    $Data::Dumper::Indent = 0;
    $Data::Dumper::Purity = 1;
    my $serialized_self = Data::Dumper::Dumper( $self );

    #See if this yearly OKM is already serialized
    my $sth = $dbh->prepare('SELECT year FROM okm_statistics WHERE year = ?');
    $sth->execute( $self->{thisYear} );
    if ($sth->fetchrow()) { #Exists in DB
        my $sth_update = $dbh->prepare('UPDATE okm_statistics SET okm_serialized = ? WHERE year = ?');
        $sth_update->execute( $serialized_self, $self->{thisYear} );
    }
    else {
        my $sth_update = $dbh->prepare('INSERT INTO okm_statistics (year, okm_serialized) VALUES (?,?)');
        $sth_update->execute( $self->{thisYear}, $serialized_self );
    }
    if ( $sth->err ) {
        return $sth->err;
    }
    return undef;
}

=head Retrieve

    C4::OPLIB::OKM::Retrieve( $year );

Gets an OKM-object from the koha.okm_statistics-table.

=cut

sub Retrieve {
    my $year = shift;
    my $dbh = C4::Context->dbh();

    my $sth = $dbh->prepare('SELECT okm_serialized FROM okm_statistics WHERE year = ?');
    $sth->execute( $year );
    my $okm_serialized = $sth->fetchrow();
    my $VAR1;
    eval $okm_serialized if $okm_serialized;
    return $VAR1;
}
1; #Happy happy joy joy!