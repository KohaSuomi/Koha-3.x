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

my $sth = $dbh->prepare("SELECT biblionumber, marcxml FROM biblioitems");
$sth->execute();                                                                         warn "Execute ".(time()-$start)."\n" if $progress;
my $marcxmls = $sth->fetchall_hashref('biblionumber');                                   warn "Fetch ".(time()-$start)."\n" if $progress;

# Get itemtypes
my $itdbh = C4::Context->dbh();
my $itsth = $dbh->prepare("SELECT itemtype FROM itemtypes");
$itsth->execute();
my $ithash = $itsth->fetchall_hashref('itemtype');

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

    print "Biblionumber $biblionumber is missing controlfields\n" unless $record->{'001'} || $record->{773};
    next unless $record->{'001'} || $record->{773};

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
    my $fixed;

    # Fixing the item's 008 MARC field
    #$fixed = fixRecord008PublicationDate($item, $itemRecord, $itemBiblio);

    # Just in case that changes were made, we have to update the marcxml values in our
    # variables to ensure that all the following fixes are done correctly. However, if you're
    # only going to use one fix at a time, these aren't necessary and can be commented.
    #$item->{biblio}->{marcxml} = $fixed unless $fixed eq "0" || $fixed eq "";

    # Fixing the item's 942c MARC field
    $fixed = fix942c($item, $itemRecord, $itemBiblio, $ithash);

    #$fixed = addEbook($item, $itemRecord);

    #$item->{biblio}->{marcxml} = $fixed unless $fixed eq "0" || $fixed eq "";

    # Fixing the item's MARC leader
    $fixed = fixRecordLeader($item, $itemRecord, $itemBiblio);
    $item->{biblio}->{marcxml} = $fixed unless $fixed eq "0" || $fixed eq "";
    $itemRecord = MARC::Record->new_from_xml( $item->{biblio}->{marcxml}, 'UTF-8', 'MARC21' ) unless $fixed eq "0" || $fixed eq "";
}

# Repaiding records that are component parts
foreach my $rcn (sort keys %componentPartRecords ) { #Get the record control numbers

    my $child = $componentPartRecords{$rcn};

    my $childRecord = MARC::Record->new_from_xml( $child->{biblio}->{marcxml}, 'UTF-8', 'MARC21' );
    my $childBiblio = C4::Biblio::GetBiblio( $child->{biblio}->{biblionumber} );
    my $fixed;

    #my $biblionumber = $child->{biblio}->{biblionumber};

    # Fixing the 773w MARC field
    #$fixed = fix773w($child, $childRecord, $childBiblio);
    #$child->{biblio}->{marcxml} = $fixed unless $fixed eq "0" || $fixed eq "";

    my $parent = $records{ getKey($child,'forParent') };

    if (not($parent)) {
        print "NO PARENT FOR CHILD ".getKey($child)."\n";
        next();
    }

    # Fix bad Component part 003s.
    # fixBadComponentPart003($child, $childRecord, $childBiblio, $parent);

    # Fixing the 773t MARC field
    #$fixed = fix773t($child, $childRecord, $childBiblio, $parent);
    #$child->{biblio}->{marcxml} = $fixed unless $fixed eq "0" || $fixed eq "";

    # Fixing the 008 MARC field
    #$fixed = fixComponentPart008PublicationDate($child, $childRecord, $childBiblio, $parent);
    #$child->{biblio}->{marcxml} = $fixed unless $fixed eq "0" || $fixed eq "";

    # Fixing the item's 942c MARC field
    $fixed = fixComponentPart942c($child, $childRecord, $childBiblio, $parent, $ithash);
    $child->{biblio}->{marcxml} = $fixed unless $fixed eq "0" || $fixed eq "";

    # Fixing the item's MARC leader
    $fixed = fixComponentPartLeader($child, $childRecord, $childBiblio, $parent);

#    unless (C4::Biblio::ModBiblio($childRecord, $biblionumber, $childBiblio->{frameworkcode})) {
#        print "<!> <!> FAILED UPDATE FOR ".$biblionumber." WITH 773w => ".$child->{773}."\n";
#    }
}

# Please note that fixRecordLeader requires that item has it's itemtype in MARC field 942c.
# This can be acquired by running the fix942c first.

sub fixRecordLeader{
    my ($item, $itemRecord, $itemBiblio) = @_;

    my $leader = $itemRecord->{'_leader'};
    my $new_leader = $leader;

    my $sf942c = getSubfield(getField($item->{biblio}->{marcxml}, '942'), 'c');
    my $sf090a = getSubfield(getField($item->{biblio}->{marcxml}, '090'), 'a');
    my $itemtype = substr($leader, 6, 2);

    # Since there only seems to be errors in am based leader itemtypes, we are only
    # fixing these.
    if($sf942c && $itemtype eq 'am'){
        # Going through the possible itemtypes

        if($sf942c eq 'NUOTTI' || $sf942c eq 'PARTIT'){
            substr($new_leader, 6, 2) = 'cm';
        }elsif($sf942c eq 'VINYL'){
            substr($new_leader, 6, 2) = 'jm';
        }elsif($sf942c eq 'CD' && $sf090a){
            if(substr($sf090a, 0, 2) eq '78'){
                substr($new_leader, 6, 2) = 'jm';
            }else{
                substr($new_leader, 6, 2) = 'im';
            }
        }

        # Now if there is difference between the leaders, we will update the MARC
        if($leader ne $new_leader){
            print "Itemtype in leader updated for item $item->{biblio}->{biblionumber}\n";
            
            my $return = updateMarcXML($new_leader, $leader, $item->{biblio}->{biblionumber});

            return $return;
        }

        return 0;
    }
}

sub fixComponentPartLeader{
    my ($child, $childRecord, $childBiblio, $parent) = @_;

    my $parentRecord = MARC::Record->new_from_xml( $parent->{biblio}->{marcxml}, 'UTF-8', 'MARC21' );
    my $leader = $childRecord->{'_leader'};
    my $new_leader = $parentRecord->{'_leader'};

    my $sf942c = getSubfield(getField($child->{biblio}->{marcxml}, '942'), 'c');
    my $sf090a = getSubfield(getField($child->{biblio}->{marcxml}, '090'), 'a');

    # Getting the parent's itemtype and callnumber from MARC if child didn't have it
    $sf942c = getSubfield(getField($parent->{biblio}->{marcxml}, '942'), 'c') unless $sf942c;
    $sf090a = getSubfield(getField($parent->{biblio}->{marcxml}, '090'), 'a') unless $sf090a;

    my $itemtype = substr($leader, 6, 2);

    # Since there only seems to be errors in am based leader itemtypes, we are only
    # fixing these.
    if($itemtype eq 'am' && $leader ne $new_leader && substr($new_leader, 6, 2) ne 'am'){
        print "Itemtype in leader updated for item $child->{biblio}->{biblionumber}\n";
            
        my $return = updateMarcXML($new_leader, $leader, $child->{biblio}->{biblionumber});

        return $return;
    }elsif($sf942c && $itemtype eq 'am'){
        # At this point the parent's item type was am or the same as child's
        # item type, so we are going to make sure that the value is correct

        $new_leader = $leader;

        if($sf942c eq 'NUOTTI' || $sf942c eq 'PARTIT'){
            substr($new_leader, 6, 2) = 'cm';
        }elsif($sf942c eq 'VINYL'){
            substr($new_leader, 6, 2) = 'jm';
        }elsif($sf942c eq 'CD' && $sf090a){
            if(substr($sf090a, 0, 2) eq '78'){
                substr($new_leader, 6, 2) = 'jm';
            }else{
                substr($new_leader, 6, 2) = 'im';
            }
        }

        # Now if there is difference between the leaders, we will update the MARC
        if($leader ne $new_leader){
            print "Itemtype in leader updated for item $child->{biblio}->{biblionumber}\n";
            
            my $return = updateMarcXML($new_leader, $leader, $child->{biblio}->{biblionumber});

            return $return;
        }

        return 0;
    }
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

sub fix773w {
    my ($child, $childRecord, $childBiblio) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    my $f773 = $child->{773};
    
    if(index($f773, ". -") != -1){
        my $old_f773 = $f773;

        $f773 =~ s/. -//;

        $child->{773} = $f773;
        print "REPAIRED ".$biblionumber." WITH 773w => ".$child->{773}."\n";

        my $return = updateMarcXML($f773, $old_f773, $biblionumber);
        return $return;
    }

    return 0;
}

sub fix773t{
    my ($child, $childRecord, $childBiblio, $parent) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    #Get parent's 245a value
    my $sf245a = getSubfield(getField($parent->{biblio}->{marcxml}, '245'), 'a');
    my $f773 = getField($child->{biblio}->{marcxml}, '773');
    my $return;

    unless($childRecord->subfield('773', 't')){
        my $sf773w = getSubfield(getField($child->{biblio}->{marcxml}, '773'), 'w');
        my $sf773wtag = '<subfield code="w">'.$sf773w.'</subfield>';
        $return = updateMarcXML($sf773wtag."\n".'    '.'<subfield code="t">'.$sf245a.'</subfield>', $sf773wtag, $biblionumber);
        print "Missing subfield data 773t added: $sf245a\n";

        return $return;
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

                $return = updateMarcXML('    <subfield code="t">'.$sf245a.'</subfield>'."\n".'  </datafield>', '  <subfield code="t">'.$sf245a.'</subfield></datafield>', $biblionumber);
            }else{
                $return = updateMarcXML('<subfield code="t">'.$sf245a.'</subfield>', '<subfield code="t">'.$sf773t.'</subfield>', $biblionumber);
            }

            print "Faulty data in 773t on record $biblionumber fixed!\n";

            return $return;
        }
    }

    return 0;
}

sub addEbook {
    my ($item, $itemRecord) = @_;
    my $biblionumber = $item->{biblio}->{biblionumber};
    my $return;

    my $f942 = getField($item->{biblio}->{marcxml}, '942');
    my $sf942c = getSubfield($f942, 'c');
    my $sf337a = getSubfield(getField($item->{biblio}->{marcxml}, '337'), 'a');

    my $sf856u = getSubfield(getField($item->{biblio}->{marcxml}, '856'), 'u');

    my $sf856z = getSubfield(getField($item->{biblio}->{marcxml}, '856'), 'z');

    my $itemtype = 'EKIRJA';

    if ($sf337a eq 'elektroninen' && $sf856u && $sf856z eq 'Lainaa e-kirja') {
        unless($sf942c){
            my $previoustag = 1000;
            # Since datafields have also index values, we have include those to be able to replace old version correctly
            my $ind1 = "ind1=\" \"";
            my $ind2 = "ind2=\" \"";

            # Getting the number of previous tag so we can insert the new tag in right spot
            foreach my $tag(@{$itemRecord->{'_fields'}}){
                if($tag->{'_tag'} > 942 && $tag->{'_tag'} < $previoustag){
                    $previoustag = $tag->{'_tag'};
                    $ind1 = "ind1=\"".$tag->{'_ind1'}."\"" if $tag->{'_ind1'} ne ' ';
                    $ind2 = "ind2=\"".$tag->{'_ind2'}."\"" if $tag->{'_ind2'} ne ' ';
                }
            }
            
            my $previoustagstring = getField($item->{biblio}->{marcxml}, $previoustag);
            
            # Let's recreate the previous tag's element so we can append the new element before it
            $previoustagstring = '  '."<datafield tag=\"$previoustag\" $ind1 $ind2>$previoustagstring</datafield>\n";
            my $fix = '  '."<datafield tag=\"942\" ind1=\" \" ind2=\" \">\n";
            $fix .= '    '."<subfield code=\"c\">".$itemtype."</subfield>\n  </datafield>\n".$previoustagstring;

            $return = updateMarcXML($fix, $previoustagstring, $biblionumber);
            print "Field 942 and subfield c created for biblionumber $biblionumber\n";
            return $return;
        } else {
            print "Record already had 942c field \n";
            return 0;
        }
    }else{
        return 0;
    }

}

sub fix942c {
    my ($item, $itemRecord, $itemBiblio, $ithash) = @_;
    my $biblionumber = $item->{biblio}->{biblionumber};
    
    my $f942 = getField($item->{biblio}->{marcxml}, '942');
    my $sf942c = getSubfield($f942, 'c');
    my $hashvalue = $ithash->{$sf942c}->{'itemtype'};
    my $updated_itype;
    my $return;

    # If the value exists and is an actual itemtype
    if($sf942c && $hashvalue){
        return 0;
    }
    if($sf942c && not $hashvalue){
        # Item has itemtype set in MARC but it doesn't exist in database
        # so it most likely is outdated. So we are going to get the updated
        # itemtype from the item.

        my $dbh = C4::Context->dbh();
        my $sth = $dbh->prepare("SELECT DISTINCT itype FROM items WHERE biblionumber = ?");
        $sth->execute($item->{biblio}->{biblionumber});

        while(my $itemtype = $sth->fetchrow_arrayref()){
            if($ithash->{@$itemtype[0]}->{'itemtype'}){
                $updated_itype = $ithash->{@$itemtype[0]}->{'itemtype'}
            }
        }

        if($updated_itype){
            # Now we can update the itemtype to MARC

            my $new942 = $f942;
            my $newtag = "<subfield code=\"c\">".$updated_itype."</subfield>";
            my $oldtag = "<subfield code=\"c\">".$sf942c."</subfield>";

            $new942 =~ s/$oldtag/$newtag/g;
            
            my $return = updateMarcXML($new942, $f942, $item->{biblio}->{biblionumber});
            
            print "Biblionumber $item->{biblio}->{biblionumber} had incorrect itemtype in MARC! Value updated!\n";
            return $return;
        }else{
            print "Biblionumber $item->{biblio}->{biblionumber} doesn't have correct itemtype in MARC or in database!\n";         
            return 0;
        }
    }

    # If the worst happened and we don't have the itemtype set in MARC, we have to get it from database
    unless($f942){
        my $dbh = C4::Context->dbh();
        my $sth = $dbh->prepare("SELECT biblionumber, itype FROM items WHERE biblionumber = ?");
        $sth->execute($biblionumber);

        my $itemtypehash = $sth->fetchall_hashref('biblionumber');
        my $itemtype = $itemtypehash->{$biblionumber}->{'itype'};

        # No sense adding the subfield if there is no itemtype for the item
        if($itemtype) {
            my $previoustag = 1000;

            # Since datafields have also index values, we have include those to be able to replace old version correctly
            my $ind1 = "ind1=\" \"";
            my $ind2 = "ind2=\" \"";

            # Getting the number of previous tag so we can insert the new tag in right spot
            foreach my $tag(@{$itemRecord->{'_fields'}}){
                if($tag->{'_tag'} > 942 && $tag->{'_tag'} < $previoustag){
                    $previoustag = $tag->{'_tag'};
                    $ind1 = "ind1=\"".$tag->{'_ind1'}."\"" if $tag->{'_ind1'} ne ' ';
                    $ind2 = "ind2=\"".$tag->{'_ind2'}."\"" if $tag->{'_ind2'} ne ' ';
                }
            }
            
            my $previoustagstring = getField($item->{biblio}->{marcxml}, $previoustag);
            
            # Let's recreate the previous tag's element so we can append the new element before it
            $previoustagstring = '  '."<datafield tag=\"$previoustag\" $ind1 $ind2>$previoustagstring</datafield>\n";
            my $fix = '  '."<datafield tag=\"942\" ind1=\" \" ind2=\" \">\n";
            $fix .= '    '."<subfield code=\"c\">".$itemtype."</subfield>\n  </datafield>\n".$previoustagstring;

            $return = updateMarcXML($fix, $previoustagstring, $biblionumber);
            print "Field 942 and subfield c created for biblionumber $biblionumber\n";
            return $return;
        }else{
            print "Biblionumber $biblionumber doesn't have an itemtype or it doesn't have an existing item!\n";
        }
    }else{
        # In this scenario we have the field 942 but it but it might not have the subfield c
        unless($sf942c){
            my $dbh = C4::Context->dbh();
            my $sth = $dbh->prepare("SELECT biblionumber, itype FROM items WHERE biblionumber = ?");
            $sth->execute($biblionumber);

            my $itemtypehash = $sth->fetchall_hashref('biblionumber');
            my $itemtype = $itemtypehash->{$biblionumber}->{'itype'};

            # No sense adding the subfield if there is no itemtype for the item
            if($itemtype){
                my $ind1 = "ind1=\" \"";
                my $ind2 = "ind2=\" \"";

                foreach my $tag(@{$itemRecord->{'_fields'}}){
                    if($tag->{'_tag'} eq '942'){
                        $ind1 = "ind1=\"".$tag->{'_ind1'}."\"" if $tag->{'_ind1'} ne ' ';
                        $ind2 = "ind2=\"".$tag->{'_ind2'}."\"" if $tag->{'_ind2'} ne ' ';
                    }
                }

                # Now we can start reconstructing the current 942 field
                my $subfield = "  <subfield code=\"c\">".$itemtype."</subfield>\n";

                my $previoustagstring = '  '."<datafield tag=\"942\" $ind1 $ind2>".$f942."</datafield>\n";

                my $check = index($previoustagstring, "code=\"c\"");

                my $newstring = '  '."<datafield tag=\"942\" $ind1 $ind2>".$f942.$subfield."  </datafield>\n";

                # Now since we are here it means that we don't have a value in 942c field
                # but that doesn't necessarily mean that the subfield doesn't exit. In this case
                # we are going to set a value in this empty field
                unless($check == -1){
                    my $refresh = $previoustagstring;
                    my $nullctag = "  <subfield code=\"c\"></subfield>\n";
                    $refresh =~ s/$nullctag/$subfield/;
                    $newstring = $refresh;
                }

                $return = updateMarcXML($newstring, $previoustagstring, $biblionumber);
                print "Subfield c added to field 942 to biblionumber $biblionumber\n";
                return $return;
            }
        }
    }

    return 0;
}

sub fixComponentPart942c {
    my ($child, $childRecord, $childBiblio, $parent, $ithash) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};
    my $parent_biblionumber = $parent->{biblio}->{biblionumber};

    my $f942 = getField($child->{biblio}->{marcxml}, '942');
    my $sf942c = getSubfield($f942, 'c');

    my $parent_f942 = getField($parent->{biblio}->{marcxml}, '942');
    my $parent_sf942c = getSubfield($parent_f942, 'c');

    my $hashvalue = $ithash->{$sf942c}->{'itemtype'};
    my $updated_itype;

    my $return;

    # If the value exists and is an actual itemtype
    if($sf942c && $hashvalue){
        return 0;
    }
    if($sf942c && not $hashvalue){
        # Item has itemtype set in MARC but it doesn't exist in database
        # so it most likely is outdated. So we are going to get the updated
        # itemtype from the item.

        my $dbh = C4::Context->dbh();
        my $sth = $dbh->prepare("SELECT DISTINCT itype FROM items WHERE biblionumber = ?");
        $sth->execute($parent->{biblio}->{biblionumber});

        while(my $itemtype = $sth->fetchrow_arrayref()){
            if($ithash->{@$itemtype[0]}->{'itemtype'}){
                $updated_itype = $ithash->{@$itemtype[0]}->{'itemtype'}
            }
        }

        if($updated_itype){
            # Now we can update the itemtype to MARC

            my $new942 = $f942;
            my $newtag = "<subfield code=\"c\">".$updated_itype."</subfield>";
            my $oldtag = "<subfield code=\"c\">".$sf942c."</subfield>";

            $new942 =~ s/$oldtag/$newtag/g;
            
            my $return = updateMarcXML($new942, $f942, $child->{biblio}->{biblionumber});
            
            print "Biblionumber $child->{biblio}->{biblionumber} had incorrect itemtype in MARC! Value updated!\n";
            return $return;
        }else{
            print "Biblionumber $child->{biblio}->{biblionumber} doesn't have correct itemtype in MARC or in database!\n";         
            return 0;
        }
    }

    unless($sf942c && $f942){
        if($parent_sf942c && $f942){
            # The best case scenario. The parent has itemtype in MARC and component Part has the field 942 in it's MARC
            my $ind1 = "ind1=\" \"";
            my $ind2 = "ind2=\" \"";

            foreach my $tag(@{$childRecord->{'_fields'}}){
                if($tag->{'_tag'} eq '942'){
                    $ind1 = "ind1=\"".$tag->{'_ind1'}."\"" if $tag->{'_ind1'} ne ' ';
                    $ind2 = "ind2=\"".$tag->{'_ind2'}."\"" if $tag->{'_ind2'} ne ' ';
                }
            }

            # Now we can start reconstructing the current 942 field
            my $subfield = "  <subfield code=\"c\">".$parent_sf942c."</subfield>\n";
            my $previoustagstring = '  '."<datafield tag=\"942\" $ind1 $ind2>".$f942."</datafield>\n";
            my $check = index($previoustagstring, "code=\"c\"");

            my $newstring = '  '."<datafield tag=\"942\" $ind1 $ind2>".$f942.$subfield."  </datafield>\n";

            # Now since we are here it means that we don't have a value in 942c field
            # but that doesn't necessarily mean that the subfield doesn't exit. In this case
            # we are going to set a value in this empty field
            unless($check == -1){
                my $refresh = $previoustagstring;
                my $nullctag = "  <subfield code=\"c\"></subfield>\n";
                $refresh =~ s/$nullctag/$subfield/;
                $newstring = $refresh;
            }

            $return = updateMarcXML($newstring, $previoustagstring, $biblionumber);
            print "Subfield c added to field 942 in biblio $biblionumber\n";
            return $return;
        }elsif($parent_sf942c){
            # Parent has the correct value in it's MARC but we don't have the 942 field
            my $previoustag = 1000;

            # Since datafields have also index values, we have include those to be able to replace old version correctly
            my $ind1 = "ind1=\" \"";
            my $ind2 = "ind2=\" \"";

            # Getting the number of previous tag so we can insert the new tag in right spot
            foreach my $tag(@{$childRecord->{'_fields'}}){
                if($tag->{'_tag'} > 942 && $tag->{'_tag'} < $previoustag){
                    $previoustag = $tag->{'_tag'};
                    $ind1 = "ind1=\"".$tag->{'_ind1'}."\"" if $tag->{'_ind1'} ne ' ';
                    $ind2 = "ind2=\"".$tag->{'_ind2'}."\"" if $tag->{'_ind2'} ne ' ';
                }
            }
            
            my $previoustagstring = getField($child->{biblio}->{marcxml}, $previoustag);
            
            # Let's recreate the previous tag's element so we append the new element after it
            $previoustagstring = '  '."<datafield tag=\"$previoustag\" $ind1 $ind2>$previoustagstring</datafield>\n";
            my $fix = '  '."<datafield tag=\"942\" ind1=\" \" ind2=\" \">\n";
            $fix .= '    '."<subfield code=\"c\">".$parent_sf942c."</subfield>\n  </datafield>\n".$previoustagstring;

            $return = updateMarcXML($fix, $previoustagstring, $biblionumber);
            print "Field 942 and subfield c created for biblionumber $biblionumber\n";

            return $return;
        }elsif($f942){
            # Here we have the 942 field but the parent doesn't have itemtype in it's MARC
            my $dbh = C4::Context->dbh();
            my $sth = $dbh->prepare("SELECT biblionumber, itype FROM items WHERE biblionumber = ?");
            $sth->execute($parent_biblionumber);

            my $itemtypehash = $sth->fetchall_hashref('biblionumber');
            my $itemtype = $itemtypehash->{$parent_biblionumber}->{'itype'};

            # If we actually have the itemtype now we can create the subfield. Otherwise there is no sense in creating one
            if($itemtype){
                my $ind1 = "ind1=\" \"";
                my $ind2 = "ind2=\" \"";

                foreach my $tag(@{$childRecord->{'_fields'}}){
                    if($tag->{'_tag'} eq '942'){
                        $ind1 = "ind1=\"".$tag->{'_ind1'}."\"" if $tag->{'_ind1'} ne ' ';
                        $ind2 = "ind2=\"".$tag->{'_ind2'}."\"" if $tag->{'_ind2'} ne ' ';
                    }
                }

                # Now we can start reconstructing the current 942 field
                my $subfield = "  <subfield code=\"c\">".$itemtype."</subfield>\n";

                my $previoustagstring = '  '."<datafield tag=\"942\" $ind1 $ind2>".$f942."</datafield>\n";

                my $check = index($previoustagstring, "code=\"c\"");

                my $newstring = '  '."<datafield tag=\"942\" $ind1 $ind2>".$f942.$subfield."  </datafield>\n";

                # Now since we are here it means that we don't have a value in 942c field
                # but that doesn't necessarily mean that the subfield doesn't exit. In this case
                # we are going to set a value in this empty field
                unless($check == -1){
                    my $refresh = $previoustagstring;
                    my $nullctag = "  <subfield code=\"c\"></subfield>\n";
                    $refresh =~ s/$nullctag/$subfield/;
                    $newstring = $refresh;
                }
                
                $return = updateMarcXML($newstring, $previoustagstring, $biblionumber);
                print "Subfield c added to field 942 in biblio $biblionumber\n";
                return $return;
            }
        }else{
            # The worst case scenario. Our parent doesn't have 942c in it's MARC and the 942 field doesn't exist in our MARC.
            my $dbh = C4::Context->dbh();
            my $sth = $dbh->prepare("SELECT biblionumber, itype FROM items WHERE biblionumber = ?");
            $sth->execute($parent_biblionumber);

            my $itemtypehash = $sth->fetchall_hashref('biblionumber');
            my $itemtype = $itemtypehash->{$parent_biblionumber}->{'itype'};

            # Checking if we got anything from database
            if($itemtype) {
                my $previoustag = 1000;

                # Since datafields have also index values, we have include those to be able to replace old version correctly
                my $ind1 = "ind1=\" \"";
                my $ind2 = "ind2=\" \"";

                # Getting the number of previous tag so we can insert the new tag in right spot
                foreach my $tag(@{$childRecord->{'_fields'}}){
                    if($tag->{'_tag'} > 942 && $tag->{'_tag'} < $previoustag){
                        $previoustag = $tag->{'_tag'};
                        $ind1 = "ind1=\"".$tag->{'_ind1'}."\"" if $tag->{'_ind1'} ne ' ';
                        $ind2 = "ind2=\"".$tag->{'_ind2'}."\"" if $tag->{'_ind2'} ne ' ';
                    }
                }
                
                my $previoustagstring = getField($child->{biblio}->{marcxml}, $previoustag);
                
                # Let's recreate the previous tag's element so we append the new element after it
                $previoustagstring = '  '."<datafield tag=\"$previoustag\" $ind1 $ind2>$previoustagstring</datafield>\n";
                my $fix = '  '."<datafield tag=\"942\" ind1=\" \" ind2=\" \">\n";
                $fix .= '    '."<subfield code=\"c\">".$itemtype."</subfield>\n  </datafield>\n".$previoustagstring;

                $return = updateMarcXML($fix, $previoustagstring, $biblionumber);
                print "Field 942 and subfield c created for biblionumber $biblionumber\n";
                return $return;
            }
        }
    }

    return 0;
}

sub fixComponentPart008PublicationDate {
    my ($child, $childRecord, $childBiblio, $parent) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};
    my $return;

    sub repair008 {
        my $year = shift;
        my $sf008 = shift;
        my $biblionumber = shift;
        my $old_sf008 = $sf008->{'_data'};
        my $return;

        if ($sf008->data() =~ /^(.{7}).{4}(.+)$/) {
            $sf008->update($1.$year.$2);

            if($old_sf008 ne $sf008->{'_data'}){
                #Only updating if the value has changed
                $return = updateMarcXML($sf008->{'_data'}, $old_sf008, $biblionumber);
                return $return;
            }
        }
        else {
            print('Record biblionumber '.$biblionumber.' has malformed field 008!'."\n");
            return 0;
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

            my $currentyear = substr(localtime(), (length localtime()) - 4, 4);

            if($year > $currentyear){
                print "Error in repairing the year. Value too high ($year), defaulting to 1899!\n";
                $year = '1899';
            }else{
                print('Record biblionumber '.$biblionumber.'\'s publication date couldn\'t be completely pulled from 260c, but repairing the year from '.$sf260c.' => '.$year."\n");
            }

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
            $return = repair008($sf260c, $f008, $biblionumber);
            return $return;
        }
    }
    else {
        if (my $sf260c = $childRecord->subfield('260','c') ) {
            $sf260c = get260c($sf260c, $biblionumber);
            $return = repair008($sf260c, $f008, $biblionumber);
        }
        elsif (getSubfield(getField($parent->{biblio}->{marcxml}, '260'), 'c')) {
            my $parentSf260c = getSubfield(getField($parent->{biblio}->{marcxml}, '260'), 'c');
            $parentSf260c = get260c($parentSf260c, $biblionumber);
            $return = repair008($parentSf260c, $f008, $biblionumber);
        }
        else {
            print("Record '$biblionumber' missing a publication date in component parts and component parent!\n");
            $return = repair008('1899', $f008, $biblionumber);
        }

        return $return;
    }

    return 0;
}

sub fixRecord008PublicationDate {
    my ($item, $itemRecord, $itemBiblio) = @_;
    my $biblionumber = $item->{biblio}->{biblionumber};
    my $return;

    sub repairTag008 {
        my $year = shift;
        my $sf008 = shift;
        my $biblionumber = shift;
        my $old_sf008 = $sf008->{'_data'};
        my $return;

        if ($sf008->data() =~ /^(.{7}).{4}(.+)$/) {
            $sf008->update($1.$year.$2);

            if($old_sf008 ne $sf008->{'_data'}){
                #Only updating if the value has changed
                $return = updateMarcXML($sf008->{'_data'}, $old_sf008, $biblionumber);

                return $return;
            }
        }
        else {
            print('Record biblionumber '.$biblionumber.' has malformed field 008!'."\n");
            return 0;
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
            
            my $currentyear = substr(localtime(), (length localtime()) - 4, 4);

            if($year > $currentyear || $year < '1899'){
                print "Error in repairing the year. Value too high ($year), defaulting to 1899!\n";
                $year = '1899';
            }else{
                print('Record biblionumber '.$biblionumber.'\'s publication date couldn\'t be completely pulled from 260c, but repairing the year from '.$sf260c.' => '.$year."\n");
            }

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
            $return = repair008($sf260c, $f008, $biblionumber);
            return $return;
        }
    }
    else {
        if (my $sf260c = $itemRecord->subfield('260','c') ) {
            $sf260c = getTag260c($sf260c, $biblionumber);
            $return = repairTag008($sf260c, $f008, $biblionumber);
        }
        elsif (getSubfield(getField($item->{biblio}->{marcxml}, '260'), 'c')) {
            my $itemSf260c = getSubfield(getField($item->{biblio}->{marcxml}, '260'), 'c');
            $itemSf260c = get260c($itemSf260c, $biblionumber);
            $return = repair008($itemSf260c, $f008, $biblionumber);
        }
        else {
            print("Record '$biblionumber' missing a publication date!\n");
            $return = repair008('1899', $f008, $biblionumber);
        }

        return $return;
    }

    return 0;
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

    return @$xml[0];
}
