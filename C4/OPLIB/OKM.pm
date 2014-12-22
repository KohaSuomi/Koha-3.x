package C4::OPLIB::OKM;

use Modern::Perl;
use Carp;

use Data::Dumper;
use URI::Escape;
use File::Temp;
use File::Basename qw( dirname );

use DateTime;

use C4::Branch;
use C4::Items;
use C4::OPLIB::OKMLibraryGroup;
use C4::Context qw(dbh);

sub new {
    my ($class, $timeperiod, $limit, $individualBranches) = @_;

    my $self = {};
    bless($self, $class);

    my $libraryGroups;
    if ($individualBranches) {
        $libraryGroups = $self->setLibraryGroups(  $self->createLibraryGroupsFromIndividualBranches($individualBranches)  );
        $self->{individualBranches} = $individualBranches;
    }
    else {
        $libraryGroups = $self->setLibraryGroups(  $self->getOKMBranchCategoriesAndBranches()  );
    }

    my ($startDate, $endDate) = StandardizeTimeperiodParameter($timeperiod);
    $self->{startDate} = $startDate;
    $self->{startDateISO} = $startDate->iso8601();
    $self->{endDate} = $endDate;
    $self->{endDateISO} = $endDate->iso8601();
    $self->{limit} = $limit; #Set the SQL LIMIT. Used in testing to generate statistics faster.

    $self->buildBiblioCache($limit); #This will take some time.

    $self->createStatistics();

    $self->releaseBiblioCache(); #As the biblio cache is a part of this OKM-object, we should release it before saving it to DB.

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

@PARAM1 hash, a koha DB row consisting of items, aqorder, statistics
=cut

sub _processItemsDataRow {
    my ($self, $libraryGroup, $row) = @_;

    my $stats = $libraryGroup->getStatistics();

    my $biblio = $self->getCachedBiblio($row->{biblionumber});
    my $primaryLanguage = $biblio->{primaryLanguage};
    my $isChildrensMaterial = IsItemChildrens($row);
    my $isFiction = $biblio->{isFiction};
    my $isMusicalRecording = $biblio->{isMusicalRecording};
    my $isAcquired = $self->isItemAcquired($row);
    my $itemtype = $row->{itype};

    #Increase the collection for every Item found
    $stats->{collection}++;
    $stats->{acquisitions}++ if $isAcquired;
    $stats->{issues} += $row->{issues};
    $stats->{expenditureAcquisitions} += $row->{price} if $row->{price};

    if ($itemtype eq 'KI') {

        $stats->{collectionBooksTotal}++;
        $stats->{acquisitionsBooksTotal}++ if $isAcquired;
        $stats->{expenditureAcquisitionsBooks} += $row->{price} if $isAcquired && $row->{price};
        $stats->{issuesBooksTotal} += $row->{issues};

        if ($primaryLanguage eq 'fin' || not(defined($primaryLanguage))) {
            $stats->{collectionBooksFinnish}++;
            $stats->{acquisitionsBooksFinnish}++ if $isAcquired;
            $stats->{issuesBooksFinnish} += $row->{issues};
        }
        elsif ($primaryLanguage eq 'swe') {
            $stats->{collectionBooksSwedish}++;
            $stats->{acquisitionsBooksSwedish}++ if $isAcquired;
            $stats->{issuesBooksSwedish} += $row->{issues};
        }
        else {
            $stats->{collectionBooksOtherLanguage}++;
            $stats->{acquisitionsBooksOtherLanguage}++ if $isAcquired;
            $stats->{issuesBooksOtherLanguage} += $row->{issues};
        }

        if ($isFiction) {
            if ($isChildrensMaterial) {
                $stats->{collectionBooksFictionJuvenile}++;
                $stats->{acquisitionsFictionJuvenile}++ if $isAcquired;
                $stats->{issuesBooksFictionJuvenile} += $row->{issues};
            }
            else { #Adults fiction
                $stats->{collectionBooksFictionAdult}++;
                $stats->{acquisitionsBooksFictionAdult}++ if $isAcquired;
                $stats->{issuesBooksFictionAdult} += $row->{issues};
            }
        }
        else { #Non-Fiction
            if ($isChildrensMaterial) {
                $stats->{collectionBooksNonFictionJuvenile}++;
                $stats->{acquisitionsNonFictionJuvenile}++ if $isAcquired;
                $stats->{issuesBooksNonFictionJuvenile} += $row->{issues};
            }
            else { #Adults Non-fiction
                $stats->{collectionBooksNonFictionAdult}++;
                $stats->{acquisitionsBooksNonFictionAdult}++ if $isAcquired;
                $stats->{issuesBooksNonFictionAdult} += $row->{issues};
            }
        }
    }
    elsif ($itemtype eq 'NU' || $itemtype eq 'PA' || $itemtype eq 'NÄ') {
        $stats->{collectionSheetMusicAndScores}++;
        $stats->{acquisitionsSheetMusicAndScores}++ if $isAcquired;
        $stats->{issuesSheetMusicAndScores} += $row->{issues};
    }
    elsif ($itemtype eq 'KA' || $itemtype eq 'CD' || $itemtype eq 'MP' || $itemtype eq 'LE') {
        if ($isMusicalRecording) {
            $stats->{collectionMusicalRecordings}++;
            $stats->{acquisitionsMusicalRecordings}++ if $isAcquired;
            $stats->{issuesMusicalRecordings} += $row->{issues};
        }
        else {
            $stats->{collectionOtherRecordings}++;
            $stats->{acquisitionsOtherRecordings}++ if $isAcquired;
            $stats->{issuesOtherRecordings} += $row->{issues};
        }
    }
    elsif ($itemtype eq 'VI') {
        $stats->{collectionVideos}++;
        $stats->{acquisitionsVideos}++ if $isAcquired;
        $stats->{issuesVideos} += $row->{issues};
    }
    elsif ($itemtype eq 'CR' || $itemtype eq 'DR') {
        $stats->{collectionCDROMs}++;
        $stats->{acquisitionsCDROMs}++ if $isAcquired;
        $stats->{issuesCDROMs} += $row->{issues};
    }
    elsif ($itemtype eq 'BR' || $itemtype eq 'DV') {
        $stats->{collectionDVDsAndBluRays}++;
        $stats->{acquisitionsDVDsAndBluRays}++ if $isAcquired;
        $stats->{issuesDVDsAndBluRays} += $row->{issues};
    }
    elsif ($itemtype ne 'AL' || $itemtype ne 'SL') { #Serials and magazines are collected from the subscriptions-table using statisticsSubscriptions()
        $stats->{collectionOther}++;
        $stats->{acquisitionsOther}++ if $isAcquired;
        $stats->{issuesOther} += $row->{issues};
    }
    else {
        carp "What is this! You shouldn't be here! There is something wrong with this items row containing this biblio:\n".$row->{biblionumber};
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
                "SELECT i.itemnumber, i.biblionumber, i.itype, i.location, i.price, ao.ordernumber, ao.datereceived, av.imageurl, i.dateaccessioned,
                        SUM(
                          IF(  s.type IN ('issue','renew') AND s.datetime BETWEEN ? AND ? AND
                               (s.usercode = 'HENKILO' OR s.usercode = 'VIRKAILIJA' OR s.usercode = 'LAPSI' OR s.usercode = 'MUUKUINLAP' OR s.usercode = 'TAKAAJA' OR s.usercode = 'YHTEISO'),
                            1,0
                          )
                        ) AS issues
                 FROM items i LEFT JOIN aqorders_items ai ON i.itemnumber = ai.itemnumber
                              LEFT JOIN aqorders ao ON ai.ordernumber = ao.ordernumber LEFT JOIN statistics s ON s.itemnumber = i.itemnumber
                              LEFT JOIN authorised_values av ON av.authorised_value = i.permanent_location
                 WHERE i.homebranch $in_libraryGroupBranches
                 GROUP BY i.itemnumber ORDER BY i.itemnumber $limit;");
    $sth->execute(  $self->{startDateISO}, $self->{endDateISO}  ); #This will take some time.....

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
                WHERE branchcode $in_libraryGroupBranches AND
                       NOT (? < startdate AND enddate < ?) $limit");
    #The SQL WHERE-clause up there needs a bit of explaining:
    # Here we find if a subscription intersects with the given timeperiod of our report.
    # Using this algorithm we can define whether two lines are on top of each other in a 1-dimensional space.
    # Think of two lines:
    #   sssssssssssssssssssssss   (subscription duration (s))
    #           tttttttttttttttttttttttttttt   (timeperiod of the report (t))
    # They cannot intersect if t.end < s.start AND s.end < t.start
    $sth->execute( $self->{endDateISO}, $self->{startDateISO} );
    my $retval = $sth->fetchrow_hashref();

    my $stats = $libraryGroup->getStatistics();
    $stats->{newspapers} = $retval->{newspapers} ? $retval->{newspapers} : 0;
    $stats->{magazines} = $retval->{magazines} ? $retval->{magazines} : 0;
    $stats->{count} = $retval->{count} ? $retval->{count} : 0;

    if ($stats->{newspapers} + $stats->{magazines} != $stats->{count}) {
        carp "Calculating subscriptions, total count ".$stats->{count}." is not the same as newspapers ".$stats->{newspapers}." and magazines ".$stats->{magazines}." combined!";
    }
}
sub statisticsDiscards {
    my ($self, $libraryGroup) = (@_);

    my $dbh = C4::Context->dbh();
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();
    my $sth = $dbh->prepare(
               "SELECT count(*) FROM deleteditems WHERE homebranch $in_libraryGroupBranches AND timestamp BETWEEN ? AND ? $limit;");
    $sth->execute( $self->{startDateISO}, $self->{endDateISO} );
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
                    FROM statistics s WHERE s.type IN ('issue','renew') AND datetime BETWEEN ? AND ?
                    GROUP BY s.borrowernumber
                 )
                 AS stat ON stat.borrowernumber = b.borrowernumber
                 WHERE b.branchcode $in_libraryGroupBranches $limit");
    $sth->execute( $self->{startDateISO}, $self->{endDateISO} );
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

sub createLibraryGroupsFromIndividualBranches {
    my ($self, $individualBranches) = @_;
    my @iBranchcodes = split(',',$individualBranches);

    my $libraryGroups = {};
    foreach my $branchcode (@iBranchcodes) {
        $libraryGroups->{$branchcode}->{branches} = {$branchcode => 1};
    }
    return $libraryGroups;
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

@PARAM1 Char, The separator to use to separate columns. Defaults to ','
=cut

sub asCsv {
    my ($self, $separator) = @_;
    my @sb;
    my $a;
    $separator = ',' unless $separator;

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
    my ($marcxml) = @_;

    my $sf = FindMarcField('084','a', $marcxml);
    if ($sf =~/^8[1-5].*/) { #ykl numbers 81.* to 85.* are fiction.
        return 1;
    }
    return 0;
}

sub IsItemMusicalRecording {
    my ($marcxml) = @_;

    my $sf = FindMarcField('084','a', $marcxml);
    if ($sf =~/^78.*/) { #ykl number 78 is a musical recording.
        return 1;
    }
    return 0;
}

sub isItemAcquired {
    my ($self, $row) = @_;

    my $startEpoch = $self->{startDate}->epoch();
    my $endEpoch = $self->{endDate}->epoch();
    my $receivedEpoch    = 0;
    my $accessionedEpoch = 0;
    if ($row->{datereceived} && $row->{datereceived} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) { #Parse ISO date
        eval { $receivedEpoch = DateTime->new(year => $1, month => $2, day => $3, time_zone => C4::Context->tz())->epoch(); };
        if ($@) { #Sometimes the DB has datetimes 0000-00-00 which is not nice for DateTime.
            $receivedEpoch = 0;
        }

    }
    if ($row->{dateaccessioned} && $row->{dateaccessioned} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) { #Parse ISO date
        eval { $accessionedEpoch = DateTime->new(year => $1, month => $2, day => $3, time_zone => C4::Context->tz())->epoch(); };
        if ($@) { #Sometimes the DB has datetimes 0000-00-00 which is not nice for DateTime.
            $accessionedEpoch = 0;
        }
    }

    #This item has been received from the vendor.
    if ($receivedEpoch) {
        return 1 if $startEpoch <= $receivedEpoch && $endEpoch >= $receivedEpoch;
        return 0; #But this item is not received during the requested timeperiod :(
    }
    #This item has been added to Koha via acquisitions, but the order hasn't been received during the requested timeperiod
    elsif ($row->{ordernumber}) {
        return 0;
    }
    #This item has been added to Koha outside of the acquisitions module
    elsif ($startEpoch <= $accessionedEpoch && $endEpoch >= $accessionedEpoch) {
        return 1; #And this item is added during the requested timeperiod
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

@RETURNS the DBI->error() -text.

=cut

sub save {
    my $self = shift;
    my $dbh = C4::Context->dbh();

    $Data::Dumper::Indent = 0;
    $Data::Dumper::Purity = 1;
    my $serialized_self = Data::Dumper::Dumper( $self );

    #See if this yearly OKM is already serialized
    my $sth = $dbh->prepare('SELECT id FROM okm_statistics WHERE startdate = ? AND enddate = ? AND individualbranches = ?');
    $sth->execute( $self->{startDateISO}, $self->{endDateISO}, $self->{individualBranches} );
    if (my $id = $sth->fetchrow()) { #Exists in DB
        my $sth_update = $dbh->prepare('UPDATE okm_statistics SET okm_serialized = ? WHERE id = ?');
        $sth_update->execute( $serialized_self, $id );
    }
    else {
        my $sth_insert = $dbh->prepare('INSERT INTO okm_statistics (startdate, enddate, individualbranches, okm_serialized) VALUES (?,?,?,?)');
        $sth_insert->execute( $self->{startDateISO}, $self->{endDateISO}, $self->{individualBranches}, $serialized_self );
    }
    if ( $sth->err ) {
        return $sth->err;
    }
    return undef;
}

=head Retrieve

    my $okm = C4::OPLIB::OKM::Retrieve( $okm_statisticsId, $startDateISO, $endDateISO, $individualBranches );

Gets an OKM-object from the koha.okm_statistics-table.
Either finds the OKM-object by the id-column, or by checking the startdate, enddate and individualbranches.
The latter is used when calculating new statistics, and firstly precalculated values are looked for. If a report
matching the given values is found, then we don't need to rerun it.

Generally you should just pass the parameters given to the OKM-object during initialization here to see if a OKM-report already exists.

@PARAM1 long, okm_statistics.id
@PARAM2 ISO8601 datetime, the start of the statistical reporting period.
@PARAM3 ISO8601 datetime, the end of the statistical reporting period.
@PARAM4 Comma-separated String, list of branchcodes to run statistics of if using the librarygroups is not desired.
=cut

sub Retrieve {
    my ($okm_statisticsId, $timeperiod, $individualBranches) = @_;

    my $okm_serialized;
    if ($okm_statisticsId) {
        $okm_serialized = _RetrieveById($okm_statisticsId);
    }
    else {
        my ($startDate, $endDate) = StandardizeTimeperiodParameter($timeperiod);
        $okm_serialized = _RetrieveByParams($startDate->iso8601(), $endDate->iso8601(), $individualBranches);
    }
    return _deserialize($okm_serialized);
}
sub _RetrieveById {
    my ($id) = @_;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT okm_serialized FROM okm_statistics WHERE id = ?');
    $sth->execute( $id );
    return $sth->fetchrow();
}
sub _RetrieveByParams {
    my ($startDateISO, $endDateISO, $individualBranches) = @_;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT okm_serialized FROM okm_statistics WHERE startdate = ? AND enddate = ? AND individualbranches = ?');
    $sth->execute( $startDateISO, $endDateISO, $individualBranches );
    return $sth->fetchrow();
}
sub RetrieveAll {
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT * FROM okm_statistics');
    $sth->execute(  );
    return $sth->fetchall_arrayref({});
}
sub _deserialize {
    my $serialized = shift;
    my $VAR1;
    eval $serialized if $serialized;
    return $VAR1;
}

=head getCachedBiblio

    my $marcxml = $okm->getCachedBiblio($biblionumber);

Due to the insane amount of marcxml data that needs to be repeatedly fetched from the db, a simple
caching mechanism is implemented to keep memory usage sane.
We fetch marcxml's to the cache when requested and automatically check the required statistics
from the marcxml, thus caching those calculations as well.
The cache size is limited by the $self->{config}->{maxCacheSize}, thus removing old marcxmls from the
cache when it gets too large.
=cut
sub getCachedBiblio {
    my ($self, $biblionumber) = @_;

    my $cache = $self->{biblioCache};
    my $cacheSize = $self->{config}->{marcxmlCacheSize};

    my ($marcxml, $biblio);
    unless ($cache->{$biblionumber}) {
        $self->{config}->{marcxmlCacheSize}++;

        #if ($self->{config}->{marcxmlCacheSize} > $self->{config}->{maxCacheSize}) {
        #    $self->{config}->{marcxmlCache} = {}; #Empty the hash, because slicing it would be tremendously slow.
        #}
        $biblio = {};
        $marcxml = C4::Biblio::GetXmlBiblio($biblionumber);
        calculateBiblioStatistics($biblio, $marcxml);

        $cache->{$biblionumber} = $biblio;
    }

    return $cache->{$biblionumber};
}

sub buildBiblioCache {
    my ($self, $limit) = @_;

    $self->{biblioCache} = {};
    my $cache = $self->{biblioCache};

    my $dbh = C4::Context->dbh();
    my $sql = "SELECT biblionumber, marcxml FROM biblioitems";
    $sql .= " LIMIT $limit" if $limit;
    my $sth = $dbh->prepare($sql);
    $sth->execute(  ); #This will take some time.....
    my $biblios = $sth->fetchall_arrayref({});
    foreach my $b (@$biblios) {
        my $biblio = {};
        calculateBiblioStatistics($biblio, $b->{marcxml});
        $cache->{$b->{biblionumber}} = $biblio;
    }
}
sub releaseBiblioCache {
    my $self = shift;

    $self->{biblioCache} = {}; #We don't need to deep delete, since there are no circular references in the cache.
}

sub calculateBiblioStatistics {
    my ($biblio, $marcxml) = @_;

    $biblio->{primaryLanguage} = FindMarcField('041','a', $marcxml);
    $biblio->{isFiction} = IsItemFiction( $marcxml);
    $biblio->{isMusicalRecording} = IsItemMusicalRecording( $marcxml);
}

=head StandardizeTimeperiodParameter

    my ($startDate, $endDate) = C4::OPLIB::OKM::StandardizeTimeperiodParameter($timeperiod);

@PARAM1 String, The timeperiod definition. Supported values are:
                1. "YYYY-MM-DD - YYYY-MM-DD" (start to end, inclusive)
                2. "YYYY" (desired year)
                3. "MM" (desired month, of the current year)
                4. "lastyear" (Calculates the whole last year)
                5. "lastmonth" (Calculates the whole previous month)
                Kills the process if no timeperiod is defined or if it is unparseable!
@RETURNS Array of DateTime, or die
=cut
sub StandardizeTimeperiodParameter {
    my ($timeperiod) = @_;

    my ($startDate, $endDate);

    if ($timeperiod =~ /^(\d\d\d\d)-(\d\d)-(\d\d) - (\d\d\d\d)-(\d\d)-(\d\d)$/) {
        #Make sure the values are correct by casting them into a DateTime
        $startDate = DateTime->new(year => $1, month => $2, day => $3, time_zone => C4::Context->tz());
        $endDate = DateTime->new(year => $4, month => $5, day => $6, time_zone => C4::Context->tz());
    }
    elsif ($timeperiod =~ /^(\d\d\d\d)$/) {
        $startDate = DateTime->from_day_of_year(year => $1, day => 1, time_zone => C4::Context->tz());
        $endDate = ($startDate->is_leap_year()) ?
                            DateTime->from_day_of_year(year => $1, day => 366, time_zone => C4::Context->tz()) :
                            DateTime->from_day_of_year(year => $1, day => 365, time_zone => C4::Context->tz());
    }
    elsif ($timeperiod =~ /^\d\d$/) {
        $startDate = DateTime->new( year => DateTime->now()->year(),
                                    month => $1,
                                    day => 1,
                                    time_zone => C4::Context->tz(),
                                   );
        $endDate = DateTime->last_day_of_month( year => $startDate->year(),
                                                month => $1,
                                                time_zone => C4::Context->tz(),
                                              ) if $startDate;
    }
    elsif ($timeperiod =~ 'lastyear') {
        $startDate = DateTime->now(time_zone => C4::Context->tz())->subtract(years => 1)->set_day(1);
        $endDate = ($startDate->is_leap_year()) ?
                DateTime->from_day_of_year(year => $startDate->year(), day => 366, time_zone => C4::Context->tz()) :
                DateTime->from_day_of_year(year => $startDate->year(), day => 365, time_zone => C4::Context->tz()) if $startDate;
    }
    elsif ($timeperiod =~ 'lastmonth') {
        $startDate = DateTime->now(time_zone => C4::Context->tz())->subtract(months => 1)->set_day(1);
        $endDate = DateTime->last_day_of_month( year => $startDate->year(),
                                                month => $startDate->month(),
                                                time_zone => $startDate->time_zone(),
                                              ) if $startDate;
    }

    if ($startDate && $endDate) {
        #Make sure the HMS portion also starts from 0 and ends at the end of day. The DB usually does timeformat casting in such a way that missing
        #complete DATETIME elements causes issues when they are automaticlly set to 0.
        $startDate->truncate(to => 'day');
        $endDate->set_hour(23)->set_minute(59)->set_second(59);
        return ($startDate, $endDate);
    }
    die "OKM->_standardizeTimeperiodParameter($timeperiod): Timeperiod '$timeperiod' could not be parsed.";
}
1; #Happy happy joy joy!