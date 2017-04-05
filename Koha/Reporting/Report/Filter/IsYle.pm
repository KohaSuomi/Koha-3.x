#!/usr/bin/perl
package Koha::Reporting::Report::Filter::IsYle;

use Modern::Perl;
use Moose;
use Data::Dumper;

extends 'Koha::Reporting::Report::Filter::Abstract';

sub BUILD {
    my $self = shift;
    $self->setName('is_yle');
    $self->setDescription('Is Yle');
    $self->setType('multiselect');
    $self->setDimension('item');
    $self->setField('is_yle');
    $self->setRule('in');
}

sub loadOptions{
    my $self = shift;
    my $dbh = C4::Context->dbh; 
    my $options = [
        {'name' => '1', 'description' => 'Is Yle'},
        {'name' => '0', 'description' => 'Not Yle'}
    ];
    
    return $options;
}

1;
