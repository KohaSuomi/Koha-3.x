#!/usr/bin/perl
package Koha::Reporting::Report::Factory;

use Modern::Perl;
use Moose;
use Data::Dumper;
use Koha::Reporting::Table::ObjectFactory;

has 'reports_class_map' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    reader => 'getReportsClassMap',
    writer => 'setReportsClassMap'
);

has 'reports_class_map_names' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
    reader => 'getReportsClassMapNames',
    writer => 'setReportsClassMapNames'
);

has 'reports_list' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
    writer => 'setReportsList'
);

has 'reports_hash' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    reader => 'getReportsHash',
    writer => 'setReportsHash'
);

has 'object_factory' => (
    is => 'rw',
    reader => 'getObjectFactory',
    writer => 'setObjectFactory'
);

sub BUILD {
    my $self = shift;
    my $objectfactory = new Koha::Reporting::Table::ObjectFactory();
    $self->setObjectFactory($objectfactory);

    $self->addReportToList('loans_by_item', 'Koha::Reporting::Report::Loans::LoansByItem');
    $self->addReportToList('loans_by_borrower_type', 'Koha::Reporting::Report::Loans::LoansByBorrowerType');
    $self->addReportToList('borrowers', 'Koha::Reporting::Report::Borrowers');
    $self->addReportToList('acquisition', 'Koha::Reporting::Report::Acquisitions');
    $self->addReportToList('acquisition_qty', 'Koha::Reporting::Report::AcquisitionsQty');
    $self->addReportToList('items', 'Koha::Reporting::Report::Items');
#    $self->addReportToList('collection_biblioitem', 'Koha::Reporting::Report::CollectionByBiblioItem');
    $self->addReportToList('deleteditems', 'Koha::Reporting::Report::DeletedItems');

#OMA
    $self->addReportToList('loans_by_item_oma', 'Koha::Reporting::Report::Oma::Loans::LoansByItem');
    $self->addReportToList('loans_by_borrower_type_oma', 'Koha::Reporting::Report::Oma::Loans::LoansByBorrowerType');
    $self->addReportToList('borrowers_oma', 'Koha::Reporting::Report::Oma::Borrowers');
    $self->addReportToList('acquisition_oma', 'Koha::Reporting::Report::Oma::Acquisitions');
    $self->addReportToList('acquisition_oma_qty', 'Koha::Reporting::Report::Oma::AcquisitionsQty');
    $self->addReportToList('items_oma', 'Koha::Reporting::Report::Oma::Items');
    $self->addReportToList('deleteditems_oma', 'Koha::Reporting::Report::Oma::DeletedItems');
    $self->addReportToList('fines_overdue', 'Koha::Reporting::Report::Oma::Fines::Overdue');
    $self->addReportToList('fines_overdue_customers', 'Koha::Reporting::Report::Oma::Fines::OverdueCustomers');

}

sub getReportByName{
    my $self = shift;
    my $reportName = $_[0];
    my $reportHash = $self->getReportsHash();
    my $report;
    if(defined $reportHash->{$reportName}){
        $report = $reportHash->{$reportName};
    }
    else{
       $report = $self->createReport($reportName);
    }
    return $report;
}

sub getReportsList{
    my $self = shift;
    my $classMap = $self->{reports_class_map_names};
    my $list = $self->{reports_list};
    if(@$list == 0){
        foreach my $reportName (@$classMap){
            $self->createReport($reportName);
        }
    }
    return $self->{reports_list};
}

sub addReportToList{
    my $self = shift;
    my $name = $_[0];
    my $class = $_[1];
    if($name && $class){
        push $self->{reports_class_map_names}, $name;
        $self->{reports_class_map}->{$name} = $class;
    }
}

sub createReport{
    my $self = shift;
    my $name = $_[0];
    my $report;
    if(defined $self->{reports_class_map}->{$name}){
        my $class = $self->{reports_class_map}->{$name};
        $report = $self->getObjectFactory()->createObject($class);
        if($report){
            $report->setName($name);
            push $self->{reports_list},  $report;
            $self->{reports_hash}->{$report->getName()} = $report;
        }
    }
    return $report;
}


1;
