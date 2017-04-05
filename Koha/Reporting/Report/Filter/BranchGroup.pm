#!/usr/bin/perl
package Koha::Reporting::Report::Filter::BranchGroup;

use Modern::Perl;
use Moose;
use Data::Dumper;
use Koha::Reporting::Table::Abstract;

extends 'Koha::Reporting::Report::Filter::Abstract';

sub BUILD {
    my $self = shift;
    $self->setName('branch_category');
    $self->setDescription('Branch Group');
    $self->setType('multiselect');
    $self->setDimension('location');
    $self->setField('branch');
    $self->setRule('in');
}

sub loadOptions{
    my $self = shift;
    my $dbh = C4::Context->dbh; 
    my $branches = [];
    
    my $stmnt = $dbh->prepare('select categorycode, categoryname from branchcategories order by categoryname');
    $stmnt->execute();
    if ($stmnt->rows >= 1){
        while ( my $row = $stmnt->fetchrow_hashref ) {
            my $option = {'name' => $row->{'categorycode'}, 'description' => $row->{'categoryname'}};
            push $branches, $option;
        }
    } 
    return $branches;
}

sub modifyOptions{
    my $self = shift;
    my $options = $_[0];
    my $dbh = C4::Context->dbh;
    my $result = [];
    if(@$options){
        my $query = 'select branchcode from branchrelations where categorycode in ( ' . $self->getArrayCondition($options) . ' )';
        my $stmnt = $dbh->prepare($query);
        $stmnt->execute();
        if ($stmnt->rows >= 1){
            while ( my $row = $stmnt->fetchrow_hashref ) {
                push $result, $row->{branchcode};
            }
            $options = $result;
        }
    }
    return $options;
}

1;
