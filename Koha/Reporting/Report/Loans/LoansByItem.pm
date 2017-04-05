#!/usr/bin/perl
package Koha::Reporting::Report::Loans::LoansByItem;

use Modern::Perl;
use Moose;
use Data::Dumper;

extends "Koha::Reporting::Report::Loans";

sub BUILD {
    my $self = shift;
    $self->setDescription('Loans by Item');
    $self->setGroup('okm');

    $self->addGrouping('Koha::Reporting::Report::Grouping::Branch');
    $self->addGrouping('Koha::Reporting::Report::Grouping::Location');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LocationType');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LocationAge');
    $self->addGrouping('Koha::Reporting::Report::Grouping::Language');
    $self->addGrouping('Koha::Reporting::Report::Grouping::ItemTypeOkm');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LoanType');
    $self->addGrouping('Koha::Reporting::Report::Grouping::CnClass');



    $self->addFilter('branch', 'Koha::Reporting::Report::Filter::Branch');
    $self->addFilter('branch_category', 'Koha::Reporting::Report::Filter::BranchGroup');
    $self->addFilter('location', 'Koha::Reporting::Report::Filter::Location');
    $self->addFilter('cn_class', 'Koha::Reporting::Report::Filter::CnClass::Primary');
#    $self->addFilter('itemtype', 'Koha::Reporting::Report::Filter::Itemtype');
    $self->addFilter('itemtype_okm', 'Koha::Reporting::Report::Filter::ItemtypeOkm');
    $self->addFilter('language', 'Koha::Reporting::Report::Filter::Language');
    $self->addFilter('published_start', 'Koha::Reporting::Report::Filter::PublishedStart');
    $self->addFilter('published_end', 'Koha::Reporting::Report::Filter::PublishedEnd');
    $self->addFilter('is_yle', 'Koha::Reporting::Report::Filter::IsYle');
    $self->addFilter('acquired_start', 'Koha::Reporting::Report::Filter::AcquiredStart');
    $self->addFilter('acquirder_end', 'Koha::Reporting::Report::Filter::AcquiredEnd');
    $self->addFilter('collection_code', 'Koha::Reporting::Report::Filter::CollectionCode');
    $self->addFilter('location_type', 'Koha::Reporting::Report::Filter::Location::Type');
    $self->addFilter('location_age', 'Koha::Reporting::Report::Filter::Location::Age');
    $self->addFilter('loan_type', 'Koha::Reporting::Report::Filter::LoanType');

    $self->addOrdering('branch', {name => 'branch', 'dimension' => 'location', 'field' => 'branch', 'alias'=> 'Branch' });
    $self->addOrdering('location', {name => 'location', 'dimension' => 'location', 'field' => 'location', 'alias'=> 'Location' }); 
}

1;
