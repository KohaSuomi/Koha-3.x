#!/usr/bin/perl
package Koha::Reporting::Report::Filter::Overdue;

use Modern::Perl;
use Moose;
use Data::Dumper;

extends 'Koha::Reporting::Report::Filter::Abstract';

sub BUILD {
    my $self = shift;
    $self->setName('overdue');
    $self->setDescription('Active / Overdue');
    $self->setType('multiselect');
    $self->setDimension('fact');
    $self->setField('is_overdue');
    $self->setRule('in');
}

sub loadOptions{
    my $self = shift;
    my $dbh = C4::Context->dbh; 
    my $options = [
        {'name' => 'Active', 'description' => 'Active'},
        {'name' => 'Overdue', 'description' => 'Overdue'}
    ];
    
    return $options;
}

1;
