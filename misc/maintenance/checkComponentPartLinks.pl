#!/bin/perl

use Modern::Perl;
use C4::Context;



=head1 SYNOPSIS

Checks all biblios in the biblioitems-table (in Koha catalog) for the component part to host record link.
Prints all component parts and their link status
Prints all host records with missing mandatory control fields
Prints a summary of findings

Is relatively fast, as it skips using Koha internals and works simply using XML-parsing tools.
Expect 2 000 000 records to be processed in 2-4 minutes

=cut


=head2 --limit

Testing/debugging purposes only

=cut

my $limit = 999999999;
#$limit = 100000;

=head2 --only-problems

Print only entries with issues, hide healthy links

=cut

my $printBadOnly = 0;

#Introduce search indices
my %map003_001ToBiblio;
#Introduce statistical counters
my $totalComponentParts = 0;
my $totalComponentPartsMissing773w = 0;
my $totalRecordsMissing001 = 0;
my $totalRecordsMissing003 = 0;
my $totalComponentPartsUnlinked = 0;
my $totalHostRecords = 0;
my $totalBadBibLevel = 0;

sub fetchBibsFromDB {
  my $dbh = C4::Context->dbh();

  my $sth = $dbh->prepare("
  SELECT biblionumber,
         ExtractValue(marcxml, \"/record/leader\") as 'leader',
         ExtractValue(marcxml, \"/record/controlfield[\@tag='001']/text()\") as '001',
         ExtractValue(marcxml, \"/record/controlfield[\@tag='003']/text()\") as '003',
         ExtractValue(marcxml, \"/record/datafield[\@tag='773']/subfield[\@code='w']/text()\") as '773w',
         ExtractValue(marcxml, \"/record/datafield[\@tag='773']/subfield\") as '773'
  FROM   biblioitems
  LIMIT  $limit
  ");
  $sth->execute();

  my $bibs = $sth->fetchall_arrayref();
  return $bibs;
}

sub buildSearchIndexes {
  my ($bibs) = @_;
  for (my $i=0 ; $i<scalar(@$bibs) ; $i++) {
    $bibs->[$i] = bless($bibs->[$i], 'Bib'); #Elevate ARRAY to a named object. A hacky Object constructor actually :)
    my $b = $bibs->[$i];
    $map003_001ToBiblio{  $b->hostLinkKey() } = $b;      #Store the identifier to this biblio if it was a host record, even component parts can have component parts
  }
  return $bibs;
}

sub iterateBibs {
  my ($bibs) = @_;
  foreach my $b (@$bibs) {
    if ($b->f773) {
      checkComponentPart($b);
    }
    else {
      checkHostRecord($b);
    }
    unless ($b->f003()) {
      $b->setMissing003();
    }
    unless ($b->f001()) {
      $b->setMissing001();
    }
  }
  return $bibs;
}

sub checkComponentPart {
  my $b = shift;
  $totalComponentParts++;
  if ($b->f773w) {
    my $hostB = $map003_001ToBiblio{$b->comPartLinkKey()};
    if ($hostB) {
      $hostB->incrementComponentPartsCount();
    }
    else {
      $b->setUnlinked();
    }
  }
  else {
    $b->setMissing773w();
  }
  unless ($b->bibLevel() =~ /^[abdci]$/) {
    $b->setBadBibLevel();
  }
}

sub checkHostRecord {
  my $b = shift;
  $totalHostRecords++;
  unless ($b->bibLevel() =~ /^[ms]$/) {
    $b->setBadBibLevel();
  }
}

sub printReport {
  my $bibs = shift;

  print "+Record analytics+\n";
  print "bibnum, linkKey, linked?, missing\n";

  foreach my $b (@$bibs) {
    my @missingFields;
    push(@missingFields, '001') if $b->missing001();
    push(@missingFields, '003') if $b->missing003();
    push(@missingFields, '773w') if $b->missing773w();

    if ($printBadOnly &&  not($b->unlinked() || @missingFields)  ) {
      next();
    }

    if ($b->f773) { #is component part
      print $b->bn().','.
            $b->comPartLinkKey().','.
            ($b->unlinked() ? 'unlinked' : 'linked').', '.
            (@missingFields ? "@missingFields" : '').', '.
            ($b->badBibLevel() ? 1 : "").', '.
            "\n";
    }
    else { #is host record
      print $b->bn().','.
            'host'.','.
            'host'.','.
            "@missingFields".', '.
            ($b->badBibLevel() ? 1 : "").', '.
            "\n"
      if @missingFields;
    }
  }
  #print totals
  print "Totals:\n";
  print "  totalComponentParts:            $totalComponentParts\n";
  print "  totalHostRecords:               $totalHostRecords\n";
  print "  totalBadBibLevel:               $totalBadBibLevel\n";
  print "  totalComponentPartsMissing773w: $totalComponentPartsMissing773w\n";
  print "  totalComponentPartsUnlinked:    $totalComponentPartsUnlinked\n";
  print "  totalRecordsMissing001:         $totalRecordsMissing001\n";
  print "  totalRecordsMissing003:         $totalRecordsMissing003\n";
}


#Do the dirty deed
printReport( iterateBibs( buildSearchIndexes( fetchBibsFromDB() ) ) );







package Bib {
sub bn {
  return $_[0]->[0];
}
sub leader {
  return $_[0]->[1];
}
sub bibLevel {
  return $_[11] if $_[11];
  $_[11] = substr($_[0]->leader(), 7, 1);
  return $_[11];
}
sub f001 {
  return $_[0]->[2];
}
sub f003 {
  return $_[0]->[3];
}
sub f773w {
  return $_[0]->[4];
}
sub f773 {
  return $_[0]->[5];
}

sub comPartLinkKey {
  return $_[0]->f003().'-'.$_[0]->f773w();
}
sub hostLinkKey {
  return $_[0]->f003().'-'.$_[0]->f001();
}

sub incrementComponentPartsCount {
  $_[0]->[6] = 0 unless $_[0]->[6];
  $_[0]->[6]++;
}
sub getComponentPartsCount {
  return $_[0]->[6];
}

sub setMissing773w {
  $_[0]->[7] = 1;
  $totalComponentPartsMissing773w++;
}
sub missing773w {
  return $_[0]->[7];
}
sub setMissing001 {
  $_[0]->[8] = 1;
  $totalRecordsMissing001++;
}
sub missing001 {
  return $_[0]->[8];
}
sub setMissing003 {
  $_[0]->[9] = 1;
  $totalRecordsMissing003++;
}
sub missing003 {
  return $_[0]->[9];
}
sub setUnlinked {
  $_[0]->[10] = 1;
  $totalComponentPartsUnlinked++;
}
sub unlinked {
  return $_[0]->[10];
}
sub setBadBibLevel {
  $_[0]->[12] = 1;
  $totalBadBibLevel++;
}
sub badBibLevel {
  return $_[0]->[12];
}

}
