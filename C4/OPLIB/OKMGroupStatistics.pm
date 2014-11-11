package C4::OPLIB::OKMGroupStatistics;

use Modern::Perl;
use Carp;

use C4::Branch;

sub new {
    my ($class) = @_;

    my $self = {};
    bless($self, $class);

    $self->{branchCategory} = 0;
    $self->{mainLibraries} = 0;
    $self->{branchLibraries} = 0;
    $self->{institutionalLibraries} = 0;
    $self->{bookmobiles} = 0;
    $self->{bookboats} = 0;
    $self->{collection} = 0;
    $self->{collectionBooksTotal} = 0;
    $self->{collectionBooksFinnish} = 0;
    $self->{collectionBooksSwedish} = 0;
    $self->{collectionBooksOtherLanguage} = 0;
    $self->{collectionBooksFictionAdult} = 0;
    $self->{collectionBooksFictionJuvenile} = 0;
    $self->{collectionBooksNonFictionAdult} = 0;
    $self->{collectionBooksNonFictionJuvenile} = 0;
    $self->{collectionSheetMusicAndScores} = 0;
    $self->{collectionMusicalRecordings} = 0;
    $self->{collectionOtherRecordings} = 0;
    $self->{collectionVideos} = 0;
    $self->{collectionCDROMs} = 0;
    $self->{collectionDVDsAndBluRays} = 0;
    $self->{collectionOther} = 0;
    $self->{acquisitions} = 0;
    $self->{acquisitionsBooksTotal} = 0;
    $self->{acquisitionsBooksFinnish} = 0;
    $self->{acquisitionsBooksSwedish} = 0;
    $self->{acquisitionsBooksOtherLanguage} = 0;
    $self->{acquisitionsBooksFictionAdult} = 0;
    $self->{acquisitionsBooksFictionJuvenile} = 0;
    $self->{acquisitionsBooksNonFictionAdult} = 0;
    $self->{acquisitionsBooksNonFictionJuvenile} = 0;
    $self->{acquisitionsSheetMusicAndScores} = 0;
    $self->{acquisitionsMusicalRecordings} = 0;
    $self->{acquisitionsOtherRecordings} = 0;
    $self->{acquisitionsVideos} = 0;
    $self->{acquisitionsCDROMs} = 0;
    $self->{acquisitionsDVDsAndBluRays} = 0;
    $self->{acquisitionsOther} = 0;
    $self->{issues} = 0;
    $self->{issuesBooksTotal} = 0;
    $self->{issuesBooksFinnish} = 0;
    $self->{issuesBooksSwedish} = 0;
    $self->{issuesBooksOtherLanguage} = 0;
    $self->{issuesBooksFictionAdult} = 0;
    $self->{issuesBooksFictionJuvenile} = 0;
    $self->{issuesBooksNonFictionAdult} = 0;
    $self->{issuesBooksNonFictionJuvenile} = 0;
    $self->{issuesSheetMusicAndScores} = 0;
    $self->{issuesMusicalRecordings} = 0;
    $self->{issuesOtherRecordings} = 0;
    $self->{issuesVideos} = 0;
    $self->{issuesCDROMs} = 0;
    $self->{issuesDVDsAndBluRays} = 0;
    $self->{issuesOther} = 0;
    $self->{newspapers} = 0;
    $self->{magazines} = 0;
    $self->{discards} = 0;
    $self->{activeBorrowers} = 0;
    $self->{expenditureAcquisitions} = 0;
    $self->{expenditureAcquisitionsBooks} = 0;

    my @printOrder = (
        'branchCategory',
        'mainLibraries',
        'branchLibraries',
        'institutionalLibraries',
        'bookmobiles',
        'bookboats',
        'collection',
        'collectionBooksTotal',
        'collectionBooksFinnish',
        'collectionBooksSwedish',
        'collectionBooksOtherLanguage',
        'collectionBooksFictionAdult',
        'collectionBooksFictionJuvenile',
        'collectionBooksNonFictionAdult',
        'collectionBooksNonFictionJuvenile',
        'collectionSheetMusicAndScores',
        'collectionMusicalRecordings',
        'collectionOtherRecordings',
        'collectionVideos',
        'collectionCDROMs',
        'collectionDVDsAndBluRays',
        'collectionOther',
        'acquisitions',
        'acquisitionsBooksTotal',
        'acquisitionsBooksFinnish',
        'acquisitionsBooksSwedish',
        'acquisitionsBooksOtherLanguage',
        'acquisitionsBooksFictionAdult',
        'acquisitionsBooksFictionJuvenile',
        'acquisitionsBooksNonFictionAdult',
        'acquisitionsBooksNonFictionJuvenile',
        'acquisitionsSheetMusicAndScores',
        'acquisitionsMusicalRecordings',
        'acquisitionsOtherRecordings',
        'acquisitionsVideos',
        'acquisitionsCDROMs',
        'acquisitionsDVDsAndBluRays',
        'acquisitionsOther',
        'issues',
        'issuesBooksTotal',
        'issuesBooksFinnish',
        'issuesBooksSwedish',
        'issuesBooksOtherLanguage',
        'issuesBooksFictionAdult',
        'issuesBooksFictionJuvenile',
        'issuesBooksNonFictionAdult',
        'issuesBooksNonFictionJuvenile',
        'issuesSheetMusicAndScores',
        'issuesMusicalRecordings',
        'issuesOtherRecordings',
        'issuesVideos',
        'issuesCDROMs',
        'issuesDVDsAndBluRays',
        'issuesOther',
        'newspapers',
        'magazines',
        'discards',
        'activeBorrowers',
        'expenditureAcquisitions',
        'expenditureAcquisitionsBooks',
    );
    $self->{printOrder} = \@printOrder;
    return $self;
}


sub asHtmlHeader {
    my ($self) = @_;

    my @sb;
    push @sb, '<thead><tr>';
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, "<td>$key</td>";
    }
    push @sb, '</tr></thead>';

    return join("\n", @sb);
}
sub asHtml {
    my ($self) = @_;

    my @sb;
    push @sb, '<tr>';
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, '<td>'.$self->{$key}.'</td>';
    }
    push @sb, '</tr>';

    return join("\n", @sb);
}

sub asCsvHeader {
    my ($self, $separator) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, "\"$key\"";
    }
    return join($separator, @sb);
}
sub asCsv {
    my ($self, $separator) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, '"'.$self->{$key}.'"';
    }

    return join($separator, @sb);
}

=head getPrintOrder

    $stats->getPrintOrder();

@RETURNS Array of Strings, all the statistical keys/columnsHeaders in the desired order.
=cut
sub getPrintOrder {
    my ($self) = @_;

    return $self->{printOrder};
}

=head getPrintOrderElements

    $stats->getPrintOrderElements();

Gets all the calculated statistical elements in the defined printOrder.
@RETURNS Pointer to an Array of Statistical Floats.
=cut
sub getPrintOrderElements {
    my ($self) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, $self->{$key};
    }

    return \@sb;
}

=head verifyStatisticalIntegrity

    my $errors = $stats->verifyStatisticalIntegrity();

@RETURNS Array of Strings, Error notifications for detected errors or undef if no errors are found.
=cut

sub verifyStatisticalIntegrity {
    my $self = shift;
    my $errors = [];

    #SUM(Branches) == branches in categorygroup.
    my $branchcodes = C4::Branch::GetBranchesInCategory( $self->{branchCategory} );
    my $branchesCount = scalar(@$branchcodes);
    my $statisticalBranchesCount =
                $self->{mainLibraries} + $self->{branchLibraries} + $self->{institutionalLibraries} + $self->{bookmobiles} + $self->{bookboats};
    if ($branchesCount != $statisticalBranchesCount) {
        push @$errors, $self->{branchCategory}.": Statistized category's branch count $statisticalBranchesCount doesn't match assigned branches count $branchesCount.\n";
    }

    my $collectionCombinedCount = 0;
    my $acquisitionsCombinedCount = 0;
    my $issuesCombinedCount = 0;
    foreach my $key (keys %$self) {
        #Collection = SUM(collection categories);
        if ($key =~ /^collection.+$/) { #It is a collection subgroup
            $collectionCombinedCount += $self->{$key};
        }
        #Acquisitions = SUM(acquisitions categories);
        if ($key =~ /^acquisitions.+$/) { #It is a acquisitions subgroup
            $acquisitionsCombinedCount += $self->{$key};
        }
        #Issues = SUM(issues categories);
        if ($key =~ /^issues.+$/) { #It is a issues subgroup
            $issuesCombinedCount += $self->{$key};
        }
    }
    if ($self->{collection} != $collectionCombinedCount) {
        push @$errors, $self->{branchCategory}.": Complete collection ".$self->{collection}." doesn't match the sum of sub-collectiongroups $collectionCombinedCount.\n";
    }
    if ($self->{acquisitions} != $acquisitionsCombinedCount) {
        push @$errors, $self->{branchCategory}.": All acquisitions ".$self->{acquisitions}." doesn't match the sum of sub-acquisitionsgroups $acquisitionsCombinedCount.\n";
    }
    if ($self->{issues} != $issuesCombinedCount) {
        push @$errors, $self->{branchCategory}.": All issues ".$self->{issues}." doesn't match the sum of sub-issuegroups $issuesCombinedCount.\n";
    }
    return $errors if scalar(@$errors) > 0;
    return undef;
}

1; #Jep hep gep