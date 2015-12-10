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

my $start = time();

my $concise = 1;
my $progress = 1;

my $dbh = C4::Context->dbh();

#Collect different types of records to their own groups.
my (%componentPartRecords, %records);

my $sth = $dbh->prepare("SELECT biblionumber, marcxml FROM biblioitems ORDER BY biblionumber DESC LIMIT 10000");
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
            $record->{773} = $content;
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



foreach my $rcn (sort keys %componentPartRecords ) { #Get the record control numbers

    my $child = $componentPartRecords{$rcn};
    my $parent = $records{ getKey($child,'forParent') };

    if (not($parent)) {
        print "NO PARENT FOR CHILD ".getKey($child)."\n";
        next();
    }

    my $childRecord = MARC::Record->new_from_xml( $child->{biblio}->{marcxml}, 'UTF-8', 'MARC21' );
    my $childBiblio = C4::Biblio::GetBiblio( $child->{biblio}->{biblionumber} );
    my $biblionumber = $child->{biblio}->{biblionumber};

    ##Fix bad Component part 003s.
    #fixBadComponentPart003($child, $childRecord, $childBiblio, $parent);
    #fix773w($child, $childRecord, $childBiblio, $parent);
    fixComponentPart008PublicationDate($child, $childRecord, $childBiblio, $parent);

#    unless (C4::Biblio::ModBiblio($childRecord, $biblionumber, $childBiblio->{frameworkcode})) {
#        print "<!> <!> FAILED UPDATE FOR ".$biblionumber." WITH 773w => ".$child->{773}."\n";
#    }
}

sub fixBadComponentPart003 {
    my ($child, $childRecord, $childBiblio, $parent) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    if ($child->{'003'} ne $parent->{'003'}) {
        print "NOT A MATCH: ".$parent->{'001'}.'-'.$parent->{'003'}." <VS> ".$child->{'001'}.'-'.$child->{'003'}."\n";

        my $f003 = $childRecord->field('003');
        $f003->update( $parent->{'003'} );

        print "REPAIRED ".$biblionumber." WITH 003 => ".$parent->{'003'}."\n";
    }
}

sub fix773w {
    my ($child, $childRecord, $childBiblio, $parent) = @_;
    my $biblionumber = $child->{biblio}->{biblionumber};

    my $f773 = $child->{773};
    #Fix bad content from usemarcon conversion
    unless ($f773 =~ /^\d+$/) {
        $child->{repair773} = 1;
        if ($f773 =~ /^(\d+). -$/) {
            $child->{773} = $1;
        }
        else {
            print "COULDNT PARSE 773w <$f773> FROM ".getKey($child)."\n";
            $child->{bad773} = 1;
        }
    }
    if ($child->{repair773}) {
        my $f773 = $childRecord->field('773');
        $f773->update( w => $child->{773} );

        print "REPAIRED ".$biblionumber." WITH 773w => ".$child->{773}."\n";
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
        $f008 = MARC::Field->new('008', '           '); #Make a blank 008
        $childRecord->insert_fields_ordered($f008);
        print('Made blank 008 for '.$biblionumber);
    }
    if ($f008->data() =~ /^.{7}\d{4}/) {
        #All is as it should be, so no repairing needed.
    }
    else {
        if (my $sf260c = $childRecord->subfield('260','c') ) {
            $sf260c = get260c($sf260c, $biblionumber);
            repair008($sf260c, $f008, $biblionumber);
        }
        elsif (my $parentSf260c = getSubfield(getField($parent->{biblio}->{marcxml}, '260'), 'c'), $biblionumber) {
            $parentSf260c = get260c($parentSf260c, $biblionumber);
            repair008($parentSf260c, $f008, $biblionumber);
        }
        else {
            print("Record biblionumber '$biblionumber' missing publication date in component parts and component parent!\n");
            repair008('1899', $f008, $biblionumber);
        }
    }
}

                                                                                         warn "Fixed 773w ".(time()-$start)."\n" if $progress;

sub storeRecordToHash {
    my ($record, $hash) = @_;

    if (exists $hash->{ getKey($record) }) {
        print "KEY: ".getKey($record)." ALREADY EXISTS!\n";
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