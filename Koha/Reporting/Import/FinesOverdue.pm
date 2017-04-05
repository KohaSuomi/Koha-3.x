#!/usr/bin/perl
package Koha::Reporting::Import::FinesOverdue;

use Modern::Perl;
use Moose;
use Data::Dumper;
use POSIX qw(strftime floor);
use Time::Piece;
use utf8;

extends 'Koha::Reporting::Import::Abstract';

sub BUILD {
    my $self = shift;
    $self->initFactTable('reporting_fines_overdue');
    $self->setName('fines_overdue_fact');
    $self->{column_transform_method}->{location}->{location} = \&locationLocation;

    $self->truncateFactTable();
}

sub loadDatas{
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $statistics;
    my @parameters;

    my $query = 'select accountlines.date as datetime, accountlines.borrowernumber, accountlines.amountoutstanding as amount, IF(accountlines.date <= DATE_SUB(CURDATE(), INTERVAL 3 YEAR), "Overdue", "Active") as is_overdue, ';
    $query .= 'borrowers.categorycode, borrowers.zipcode as postcode, borrowers.dateofbirth, borrowers.cardnumber , borrowers.branchcode as branch ';
    $query .= 'from accountlines ';
    $query .= 'left join borrowers on accountlines.borrowernumber = borrowers.borrowernumber ';
    $query .= 'where accountlines.amountoutstanding > 0 ';

#    if($self->getLastSelectedId()){
#        $query .= "and accountlines.date > ? ";
#        push @parameters, $self->getLastSelectedId();
#    }
#    if($self->getLastAllowedId()){
#        $query .= "and accountlines.date <= ? ";
#        push @parameters, $self->getLastAllowedId();
#    }
    $query .= 'order by datetime ';

    if($self->getLimit()){
        $query .= 'limit ?';
        push @parameters, $self->getLimit();
    }


#    print Dumper $query;

    my $stmnt = $dbh->prepare($query);
    if(@parameters){
        $stmnt->execute(@parameters) or die($DBI::errstr);
    }
    else{
        $stmnt->execute() or die($DBI::errstr);
    }

    if ($stmnt->rows >= 1){
        $statistics = $stmnt->fetchall_arrayref({});
        if(defined @$statistics[-1]){
            my $lastRow =  @$statistics[-1];
            if(defined $lastRow->{datetime}){
                $self->updateLastSelected($lastRow->{datetime});
            }
        }
    }
#    print Dumper $statistics;
    
    return $statistics;
}

sub loadLastAllowedId{
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $query = "select MAX(date) from accountlines order by date";
    my $stmnt = $dbh->prepare($query);
    $stmnt->execute() or die($DBI::errstr);

    my $lastId;
    if($stmnt->rows == 1){
        $lastId = $stmnt->fetch()->[0];
        $self->setLastAllowedId($lastId);
    }
}

sub truncateFactTable{
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $query = "truncate reporting_fines_overdue_fact";
    my $stmnt = $dbh->prepare($query);
    $stmnt->execute() or die($DBI::errstr);
}

sub locationLocation{
  return 'AIK';
}
