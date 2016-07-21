#!/usr/bin/perl

=head SYNOPSIS

This script fixes component part issues:

-Bad link relation, 773w -> 001 && 003 -> 003
-Missing publicationdate from component parts 008, this causes component parts to not sort properly by publicationdate.

When finding component part relations you can define if you want to match with 773w -> 001 only,
or include the 003 -> 003 safety matching as well.
Needless to say, if your 003 -> 003 linkings are broken, then you should only link using 773w -> 001.
This has the downside that if you have records sharing the same 001
    (which is completely legal, we have record control number at 001 and record control identifier at 003)
you will get wrong linkings. This should be quite rare however.

You can toggle this linking in getKey(), by commenting code.

=cut

use Modern::Perl;
use Getopt::Long;
use Error qw(:try);

use MARC::Field;

use C4::Context;
use C4::Biblio;
use Data::Dumper;

my $start = time();

my $concise = 1;
my $progress = 1;

my $dbh = C4::Context->dbh();

#Collect different types of records to their own groups.
my (%componentPartRecords, %records);

my $sth = $dbh->prepare("SELECT biblionumber, marcxml FROM biblioitems;");
$sth->execute();                                                                         warn "Execute ".(time()-$start)."\n" if $progress;
my $marcxmls = $sth->fetchall_hashref('biblionumber');                                   warn "Fetch ".(time()-$start)."\n" if $progress;

#Get component parts
my $conflicting001 = 0;
my $c=0;
foreach my $biblionumber (sort keys %$marcxmls ) {       $c++;
    if ($c+1 % 100 == 0) {
        print "\n$c";
    }
    else {
        print ".";
    }

    my $marcxml = $marcxmls->{$biblionumber}->{marcxml};
    my $record = {};
    $record->{biblio} = $marcxmls->{$biblionumber};

    my $isAComponentPart = 0;

    if (my $field = getField($marcxml, '001')) {
        $record->{'001'} = $field;
    }
    if (my $field = getField($marcxml, '003')) {
        $record->{'003'} = $field;
    }
    if (my $field = getField($marcxml, '773')) {
        if (my $content = getSubfield($field, 'w')) {
            $record->{773} = $content; # Getting rid of unnecessary marks
            $isAComponentPart = 1;
        }
    }
    else {
        $isAComponentPart = 0;
    }

    if ($isAComponentPart) {
        $conflicting001 = 1 unless storeRecordToHash($record, \%componentPartRecords);
    }
    else {
        $conflicting001 = 1 unless storeRecordToHash($record, \%records);
    }
}

                                                                                         warn "Gathered ".(time()-$start)."\n" if $progress;

# Repairing basic records
foreach my $rcn (sort keys %records ) { #Get the record control numbers

    my $item = $records{$rcn};

    my $itemRecord = MARC::Record->new_from_xml( $item->{biblio}->{marcxml}, 'UTF-8', 'MARC21' );
    my $itemBiblio = C4::Biblio::GetBiblio( $item->{biblio}->{biblionumber} );

    #Add missing 003 field
    add003($item, $itemRecord);

    fixRecord008PublicationDate($item, $itemRecord, $itemBiblio);

    
}

# Repaiding records that are component parts
foreach my $rcn (sort keys %componentPartRecords ) { #Get the record control numbers

    my $child = $componentPartRecords{$rcn};

    my $childRecord = MARC::Record->new_from_xml( $child->{biblio}->{marcxml}, 'UTF-8', 'MARC21' );
    my $childBiblio = C4::Biblio::GetBiblio( $child->{biblio}->{biblionumber} );

    #my $biblionumber = $child->{biblio}->{biblionumber};
    addchild003($child, $childRecord);
    fix773w($child, $childRecord, $childBiblio);

    my $parent = $records{ getKey($child,'forParent') };

    if (not($parent)) {
        print "NO PARENT FOR CHILD ".getKey($child)."\n";
        next();
    }

    ##Fix bad Component part 003s.
    #fixBadComponentPart003($child, $childRecord, $childBiblio, $parent);

    fix773t($child, $childRecord, $childBiblio, $parent);
    fixComponentPart008PublicationDate($child, $childRecord, $childBiblio, $parent);

#    unless (C4::Biblio::ModBiblio($childRecord, $biblionumber, $childBiblio->{frameworkcode})) {
#        print "<!> <!> FAILED UPDATE FOR ".$biblionumber." WITH 773w => ".$child->{773}."\n";
#    }
}

sub fixBadComponentPart003 {
    my ($child, $childRecord, $childBiblio, $parent, $parentRecord, $parentBiblio) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    if ($child->{'003'} ne $parent->{'003'}) {
        print "NOT A MATCH: ".$parent->{'001'}.'-'.$parent->{'003'}." <VS> ".$child->{'001'}.'-'.$child->{'003'}."\n";

        my $f003 = $childRecord->field('003');
        $f003->update( $parent->{'003'} );

        print "REPAIRED ".$biblionumber." WITH 003 => ".$parent->{'003'}."\n";
    }
}

sub addchild003 {
    my ($child, $childRecord) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    my $f003 = $childRecord->field('003');

    my $newdata = 'FI-Kyyti';

    unless($f003){
        $f003 = MARC::Field->new('003', $newdata); #Make a new 003
        $childRecord->insert_fields_ordered($f003);
        my @tags = ('001');
        my $existingField = 0; # Testing whether or not we have found the previous element

        for my $tag(@tags){
            if(getField($child->{biblio}->{marcxml}, $tag) and $existingField == 0){
                my $previousField = getField($child->{biblio}->{marcxml}, $tag);

                my $tag = "<controlfield tag=\"$tag\">$previousField</controlfield>";
                my $value = $childRecord->field('003')->{'_data'};

                my $newtag = $tag."\n".'  '."<controlfield tag=\"003\">".$value."</controlfield>";

                my $xml = $child->{biblio}->{marcxml};
                $xml =~ s/$tag/$newtag/;

                updateMarcXML($xml, $child->{biblio}->{marcxml}, $biblionumber);
                $existingField = 1;
            }
        }
        print "Missing control field data 003 added $newdata for $biblionumber\n";
    } else {
        print "Record already had 003 field \n";
    }
}

sub fix773w {
    my ($child, $childRecord, $childBiblio) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    my $f773 = $child->{773};
    
    if(index($f773, ". -") != -1){
        my $old_f773 = $f773;

        $f773 =~ s/. -//;

        $child->{773} = $f773;
        print "REPAIRED ".$biblionumber." WITH 773w => ".$child->{773}."\n";

        updateMarcXML($f773, $old_f773, $biblionumber);
    }
}

sub fix773t{
    my ($child, $childRecord, $childBiblio, $parent) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    #Get parent's 245a value
    my $sf245a = getSubfield(getField($parent->{biblio}->{marcxml}, '245'), 'a');
    my $f773 = getField($child->{biblio}->{marcxml}, '773');

    unless($childRecord->subfield('773', 't')){
        my $sf773w = getSubfield(getField($child->{biblio}->{marcxml}, '773'), 'w');
        my $sf773wtag = '<subfield code="w">'.$sf773w.'</subfield>';
        updateMarcXML($sf773wtag."\n".'    '.'<subfield code="t">'.$sf245a.'</subfield>', $sf773wtag, $biblionumber);
        print "Missing subfield data 773t added: $sf245a\n";
    }else{
        #Get child's 773t value

        my $marc = $child->{biblio}->{marcxml};
        my $f773 = getField($marc, '773');
        my $sf773t = getSubfield($f773, 't');

        my $length = length $sf245a;
        my $parentstring = substr($sf245a, 0, $length/2);

        # Checking if the parentstring exists in the 773t field (Even just half of the string is enough)

        if(index($sf773t, $parentstring) == -1){
            if(index($marc, '  <subfield code="t">'.$sf245a.'</subfield></datafield>') != -1){
                # Here we are cleaning up the marcxml to look correct. This must be done because otherwise
                # we end up updating marcxml every time the script is run. With this fix it will go through the "validator"

                updateMarcXML('    <subfield code="t">'.$sf245a.'</subfield>'."\n".'  </datafield>', '  <subfield code="t">'.$sf245a.'</subfield></datafield>', $biblionumber);
            }else{
                updateMarcXML('<subfield code="t">'.$sf245a.'</subfield>', '<subfield code="t">'.$sf773t.'</subfield>', $biblionumber);
            }

            print "Faulty data in 773t on record $biblionumber fixed!\n";
        }
    }
}


sub fixComponentPart008PublicationDate {
    my ($child, $childRecord, $childBiblio, $parent) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    sub repair008 {
        my $year = shift;
        my $sf008 = shift;
        my $biblionumber = shift;
        my $old_sf008 = $sf008->{'_data'};

        if ($sf008->data() =~ /^(.{7}).{4}(.+)$/) {
            $sf008->update($1.$year.$2);

            if($old_sf008 ne $sf008->{'_data'}){
                #Only updating if the value has changed
                updateMarcXML($sf008->{'_data'}, $old_sf008, $biblionumber);
            }
        }
        else {
            print('Record biblionumber '.$biblionumber.' has malformed field 008!'."\n");
        }
    }
    sub get260c {
        my ($sf260c, $biblionumber) = @_;
        return 0 unless $sf260c;

        if ($sf260c =~ /(\d{4})/) {
            return $1;
        }
        #Trying to get somekind of a year out of this, usually 260c seems to be like [198-?] or [19-?] etc.
        elsif ($sf260c =~ /(\d{2,4})/) {
            my $year = $1;

            while (length $year < 4) { #this created a length 4 string, as full length is reached on last loop iteration
                $year .= '0';
            }
            print('Record biblionumber '.$biblionumber.'\'s publication date couldn\'t be completely pulled from 260c, but repairing the year from '.$sf260c.' => '.$year."\n");
            return $year;
        }
        else {
            print('Biblionumber '.$biblionumber.'\'s 260c couldnt be parsed. No year found from 260c => '.$sf260c.'. Using 1899.'."\n");
            return '1899';
        }
    }

    my $f008 = $childRecord->field('008');
    unless ($f008) {
        $f008 = MARC::Field->new('008', '       uuuu                             '); #Make a blank 008
        $childRecord->insert_fields_ordered($f008);

        # List of possible elements before the tag 008. Leaving leader and record tags out of this array
        # because if we don't have the other ones we already have bigger problems than missing 008 tag
        my @tags = ('007', '006', '005', '003', '001');
        my $existingField = 0; # Testing whether or not we have found the previous element

        for my $tag(@tags){
            if(getField($child->{biblio}->{marcxml}, $tag) and $existingField == 0){
                my $previousField = getField($child->{biblio}->{marcxml}, $tag);

                my $tag = "<controlfield tag=\"$tag\">$previousField</controlfield>";
                my $value = $childRecord->field('008')->{'_data'};

                my $newtag = $tag."\n".'  '."<controlfield tag=\"008\">".$value."</controlfield>";

                my $xml = $child->{biblio}->{marcxml};
                $xml =~ s/$tag/$newtag/;

                #We must update the marcxml at this point so that we can update the correct publish date later on
                updateMarcXML($xml, $child->{biblio}->{marcxml}, $biblionumber);
                $existingField = 1;
            }
        }

        print('Made blank 008 for '.$biblionumber."\n");
    }
    if ($f008->data() =~ /^.{7}\d{4}/) {
        # Everything seems to be fine, but we still have to check if the year is correct
        my $year = substr($f008->data(), 7, 4);
        my $sf260c;

        # Getting the 260c value
        if (getSubfield(getField($parent->{biblio}->{marcxml}, '260'), 'c')) {
            $sf260c = getSubfield(getField($parent->{biblio}->{marcxml}, '260'), 'c');
            $sf260c = get260c($sf260c, $biblionumber);
        }elsif(getField($parent->{biblio}->{marcxml}, '008')){ # If the 260c field doesn't exist, we're getting the value from 008 field
            my $f008 = getField($parent->{biblio}->{marcxml}, '008');
            $sf260c = substr($f008, 7, 4);
        }
        else {
            $sf260c = '1899';
        }

        # Parsing the 260c to comparable format
        if ($sf260c =~ /(\d{4})/) {
            $sf260c = $1;
        }
        elsif ($sf260c =~ /(\d{2,4})/) {
            my $year = $1;

            while (length $year < 4) { #this created a length 4 string, as full length is reached on last loop iteration
                $year .= '0';
            }

            $sf260c = $year;
        }

        # And now let's do the comparison
        if($year ne $sf260c){
            print "Biblionumber $biblionumber had incorrect value in 008 publication year! Value has been repaired!\n";
            repair008($sf260c, $f008, $biblionumber);
        }
    }
    else {
        if (my $sf260c = $childRecord->subfield('260','c') ) {
            $sf260c = get260c($sf260c, $biblionumber);
            repair008($sf260c, $f008, $biblionumber);
        }
        elsif (getSubfield(getField($parent->{biblio}->{marcxml}, '260'), 'c')) {
            my $parentSf260c = getSubfield(getField($parent->{biblio}->{marcxml}, '260'), 'c');
            $parentSf260c = get260c($parentSf260c, $biblionumber);
            repair008($parentSf260c, $f008, $biblionumber);
        }
        else {
            print("Record '$biblionumber' missing a publication date in component parts and component parent!\n");
            repair008('1899', $f008, $biblionumber);
        }
    }
}

sub add003 {
    my ($item, $itemRecord) = @_;
    my $biblionumber = $item->{biblio}->{biblionumber};

    my $f003 = $itemRecord->field('003');

    my $newdata = 'FI-Kyyti';

    unless($f003){
        $f003 = MARC::Field->new('003', $newdata); #Make a new 003
        $itemRecord->insert_fields_ordered($f003);
        my @tags = ('001');
        my $existingField = 0; # Testing whether or not we have found the previous element

        for my $tag(@tags){
            if(getField($item->{biblio}->{marcxml}, $tag) and $existingField == 0){
                my $previousField = getField($item->{biblio}->{marcxml}, $tag);

                my $tag = "<controlfield tag=\"$tag\">$previousField</controlfield>";
                my $value = $itemRecord->field('003')->{'_data'};

                my $newtag = $tag."\n".'  '."<controlfield tag=\"003\">".$value."</controlfield>";

                my $xml = $item->{biblio}->{marcxml};
                $xml =~ s/$tag/$newtag/;

                updateMarcXML($xml, $item->{biblio}->{marcxml}, $biblionumber);
                $existingField = 1;
            }
        }
        print "Missing control field data 003 added $newdata for $biblionumber\n";
    } else {
        #print "Record already had 003 field \n";
    }

}

sub fixRecord008PublicationDate {
    my ($item, $itemRecord, $itemBiblio) = @_;
    my $biblionumber = $item->{biblio}->{biblionumber};

    sub repairTag008 {
        my $year = shift;
        my $sf008 = shift;
        my $biblionumber = shift;
        my $old_sf008 = $sf008->{'_data'};

        if ($sf008->data() =~ /^(.{7}).{4}(.+)$/) {
            $sf008->update($1.$year.$2);

            if($old_sf008 ne $sf008->{'_data'}){
                #Only updating if the value has changed
                updateMarcXML($sf008->{'_data'}, $old_sf008, $biblionumber);
            }
        }
        else {
            print('Record biblionumber '.$biblionumber.' has malformed field 008!'."\n");
        }
    }
    sub getTag260c {
        my ($sf260c, $biblionumber) = @_;
        return 0 unless $sf260c;

        if ($sf260c =~ /(\d{4})/) {
            return $1;
        }
        #Trying to get somekind of a year out of this, usually 260c seems to be like [198-?] or [19-?] etc.
        elsif ($sf260c =~ /(\d{2,4})/) {
            my $year = $1;

            while (length $year < 4) { #this created a length 4 string, as full length is reached on last loop iteration
                $year .= '0';
            }
            print('Record biblionumber '.$biblionumber.'\'s publication date couldn\'t be completely pulled from 260c, but repairing the year from '.$sf260c.' => '.$year."\n");
            return $year;
        }
        else {
            print('Biblionumber '.$biblionumber.'\'s 260c couldnt be parsed. No year found from 260c => '.$sf260c.'. Using 1899.'."\n");
            return '1899';
        }
    }

    my $f008 = $itemRecord->field('008');
    unless ($f008) {
        $f008 = MARC::Field->new('008', '       uuuu                             '); #Make a blank 008
        $itemRecord->insert_fields_ordered($f008);

        # List of possible elements before the tag 008. Leaving leader and record tags out of this array
        # because if we don't have the other ones we already have bigger problems than missing 008 tag
        my @tags = ('007', '006', '005', '003', '001');
        my $existingField = 0; # Testing whether or not we have found the previous element

        for my $tag(@tags){
            if(getField($item->{biblio}->{marcxml}, $tag) and $existingField == 0){
                my $previousField = getField($item->{biblio}->{marcxml}, $tag);

                my $tag = "<controlfield tag=\"$tag\">$previousField</controlfield>";
                my $value = $itemRecord->field('008')->{'_data'};

                my $newtag = $tag."\n".'  '."<controlfield tag=\"008\">".$value."</controlfield>";

                my $xml = $item->{biblio}->{marcxml};
                $xml =~ s/$tag/$newtag/;

                updateMarcXML($xml, $item->{biblio}->{marcxml}, $biblionumber);
                $existingField = 1;
            }
        }

        print('Made blank 008 for '.$biblionumber."\n");
    }

    if ($f008->data() =~ /^.{7}\d{4}/) {
        # Everything seems to be fine, but we still have to check if the year is correct
        my $year = substr($f008->data(), 7, 4);
        my $sf260c;

        # Getting the 260c value
        if (getSubfield(getField($item->{biblio}->{marcxml}, '260'), 'c')) {
            $sf260c = getSubfield(getField($item->{biblio}->{marcxml}, '260'), 'c');
            $sf260c = get260c($sf260c, $biblionumber);
        }elsif(getField($item->{biblio}->{marcxml}, '008')){ # If the 260c field doesn't exist, we're getting the value from 008 field
            my $f008 = getField($item->{biblio}->{marcxml}, '008');
            $sf260c = substr($f008, 7, 4);
        }
        else {
            $sf260c = '1899';
        }

        # Parsing the 260c to comparable format
        if ($sf260c =~ /(\d{4})/) {
            $sf260c = $1;
        }
        elsif ($sf260c =~ /(\d{2,4})/) {
            my $year = $1;

            while (length $year < 4) { #this created a length 4 string, as full length is reached on last loop iteration
                $year .= '0';
            }

            $sf260c = $year;
        }

        # And now let's do the comparison
        if($year ne $sf260c){
            print "Biblionumber $biblionumber had incorrect value in 008 publication year! Value has been repaired!\n";
            repair008($sf260c, $f008, $biblionumber);
        }
    }
    else {
        if (my $sf260c = $itemRecord->subfield('260','c') ) {
            $sf260c = getTag260c($sf260c, $biblionumber);
            repairTag008($sf260c, $f008, $biblionumber);
        }
        elsif (getSubfield(getField($item->{biblio}->{marcxml}, '260'), 'c')) {
            my $itemSf260c = getSubfield(getField($item->{biblio}->{marcxml}, '260'), 'c');
            $itemSf260c = get260c($itemSf260c, $biblionumber);
            repair008($itemSf260c, $f008, $biblionumber);
        }
        else {
            print("Record '$biblionumber' missing a publication date!\n");
            repair008('1899', $f008, $biblionumber);
        }
    }
}

                                                                                         warn "Fixed 773w ".(time()-$start)."\n" if $progress;

sub storeRecordToHash {
    my ($record, $hash) = @_;

    if (exists $hash->{ getKey($record) }) {
        #print "KEY: ".getKey($record)." ALREADY EXISTS!\n";
        return 0; #We found a conflicting 001
    }
    else {
        $hash->{ getKey($record) } = $record;
    }
    return 1;
}

sub getKey {
    my ($record, $forParent) = @_;
    ### 773w + 003 linking
    #if ($forParent) {
    #    return $record->{'773'}.'-'.$record->{'003'};
    #}
    #return $record->{'001'}.'-'.$record->{'003'};

    ### 773w linking only
    if ($forParent) {
        return $record->{'773'};
    }
    return $record->{'001'};
}

sub getField {
    my ($marcxml, $tag) = @_;

    if ($marcxml =~ /^\s{2}<(data|control)field tag="$tag".*?>(.*?)<\/(data|control)field>$/sm) {
        return $2;
    }
    return 0;
}
sub getSubfield {
    my ($fieldxml, $subfield) = @_;

    if ($fieldxml =~ /^\s{4}<subfield code="$subfield">(.*?)<\/subfield>$/sm) {
        return $1;
    }
    return 0;
}

sub updateMarcXML{
    my ($value, $old_value, $biblionumber) = @_;

    my $sth = $dbh->prepare("SELECT marcxml FROM biblioitems WHERE biblionumber = ?");
    $sth->execute($biblionumber);

    my $xml = $sth->fetchrow_arrayref();

    $old_value = quotemeta $old_value; # escape regex metachars if present

    @$xml[0] =~ s/$old_value/$value/g;

    $sth = $dbh->prepare("UPDATE biblioitems SET marcxml = ? WHERE biblionumber = ?");
    $sth->execute(@$xml[0], $biblionumber);
}
