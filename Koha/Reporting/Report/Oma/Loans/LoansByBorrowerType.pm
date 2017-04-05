#!/usr/bin/perl
package Koha::Reporting::Report::Oma::Loans::LoansByBorrowerType;

use Modern::Perl;
use Moose;
use Data::Dumper;

extends "Koha::Reporting::Report::Loans";

sub BUILD {
    my $self = shift;
    $self->setDescription('Loans by Borrower type');
    $self->setGroup('oma');

    $self->addGrouping('Koha::Reporting::Report::Grouping::Branch');
    $self->addGrouping('Koha::Reporting::Report::Grouping::Location');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LocationType');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LocationAge');
    $self->addGrouping('Koha::Reporting::Report::Grouping::Language');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LoanType');
    $self->addGrouping('Koha::Reporting::Report::Grouping::Postcode');
    $self->addGrouping('Koha::Reporting::Report::Grouping::CnClass');

    $self->addFilter('branch', 'Koha::Reporting::Report::Filter::Branch');
    $self->addFilter('branch_category', 'Koha::Reporting::Report::Filter::BranchGroup');
    $self->addFilter('location', 'Koha::Reporting::Report::Filter::Location');
    $self->addFilter('cn_class', 'Koha::Reporting::Report::Filter::CnClass::Primary');
    $self->addFilter('itemtype', 'Koha::Reporting::Report::Filter::Itemtype');
    $self->addFilter('language', 'Koha::Reporting::Report::Filter::Language');
    $self->addFilter('location_type', 'Koha::Reporting::Report::Filter::Location::Type');
    $self->addFilter('location_age', 'Koha::Reporting::Report::Filter::Location::Age');
    $self->addFilter('loan_type', 'Koha::Reporting::Report::Filter::LoanType');

}

1;
